#!/usr/bin/env bash
# vm2api 一键升级：拉上游 → rebase 你的改动 → 构建 → 切换 → 冒烟 → 失败回滚
# 用法:
#   scripts/upgrade.sh            # 正常升级
#   scripts/upgrade.sh --check    # 只看有没有新版，不动任何东西
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY="${VM2API_DEPLOY_DIR:-/opt/vm2api}"
ENVF="$DEPLOY/.env"
BACKUP="$DEPLOY/.env.upgrade-bak"
IMAGE_REPO="local/vm2api"
MODE="${1:-}"

say() { printf '\033[36m▶\033[0m %s\n' "$*"; }
ok()  { printf '\033[32m✓\033[0m %s\n' "$*"; }
die() { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

[ -f "$ENVF" ] || die "找不到 $ENVF"
[ -d "$SRC/.git" ] || die "$SRC 不是 git 仓库"

cd "$SRC"

# ---------- 1. 工作区必须干净 ----------
if [ -n "$(git status --porcelain)" ]; then
  git status --short
  die "工作区有未提交改动。先 git commit，或 git stash"
fi

# ---------- 2. 拉上游 ----------
say "拉取上游 tags"
git fetch --quiet --tags --force upstream

LATEST="$(git tag --list 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)"
[ -n "$LATEST" ] || die "拿不到上游 tag"
CURRENT_TAG="v$(cat "$DEPLOY/VERSION" | tr -d '[:space:]')"

echo "  当前安装: $CURRENT_TAG"
echo "  上游最新: $LATEST"

if [ "$MODE" = "--check" ]; then
  if [ "$LATEST" = "$CURRENT_TAG" ]; then ok "已是最新"; else say "有新版可升级"; fi
  exit 0
fi

if [ "$LATEST" = "$CURRENT_TAG" ] && [ "$MODE" != "--rebuild" ]; then
  ok "已是最新 $CURRENT_TAG，无需操作（要强制重建用 --rebuild）"
  exit 0
fi

# ---------- 3. rebase 你的改动 ----------
say "把你的改动接到 $LATEST 上"
if ! git rebase "$LATEST"; then
  echo
  echo "有冲突，需要手动处理："
  git status --short
  echo "  解决后: git add <file> && git rebase --continue"
  echo "  放弃:   git rebase --abort"
  exit 1
fi
ok "rebase 完成"

PATCH_COUNT="$(git rev-list --count "$LATEST"..HEAD)"
VER="${LATEST#v}"
NEW_TAG="${VER}-p${PATCH_COUNT}"
FULL_IMAGE="${IMAGE_REPO}:${NEW_TAG}"
echo "  你的改动: ${PATCH_COUNT} 个提交"
echo "  目标镜像: ${FULL_IMAGE}"

# ---------- 4. 构建 ----------
say "构建镜像（几分钟，别中断）"
VM2API_IMAGE="$IMAGE_REPO" VM2API_IMAGE_TAG="$NEW_TAG" \
  docker compose -f docker-compose.yml -f docker-compose.build.yml build
ok "构建完成: $FULL_IMAGE"

# ---------- 5. 备份并切换 ----------
cp -f "$ENVF" "$BACKUP"
PREV_IMAGE="$(grep -E '^VM2API_IMAGE=' "$ENVF" | tail -1 | cut -d= -f2- || true)"
PREV_TAG="$(grep -E '^VM2API_IMAGE_TAG=' "$ENVF" | tail -1 | cut -d= -f2- || true)"
PREV_TAG="${PREV_TAG:-}"

set_env() {
  local k="$1" v="$2"
  if grep -qE "^${k}=" "$ENVF"; then
    sed -i "s|^${k}=.*|${k}=${v}|" "$ENVF"
  else
    printf '%s=%s\n' "$k" "$v" >>"$ENVF"
  fi
}
set_env VM2API_IMAGE "$IMAGE_REPO"
set_env VM2API_IMAGE_TAG "$NEW_TAG"

say "切换容器到 $NEW_TAG"
cd "$DEPLOY"
if ! docker compose up -d; then
  say "启动失败，回滚"
  cp -f "$BACKUP" "$ENVF"
  docker compose up -d || true
  die "已回滚到 ${PREV_TAG:-旧版本}"
fi

# ---------- 6. 冒烟 ----------
smoke() {
  local i
  for i in $(seq 1 45); do
    if curl -fsS --noproxy '*' -o /dev/null "http://127.0.0.1:8787/health" 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  return 1
}

say "等待健康检查"
if ! smoke; then
  docker logs --tail 40 vm2api || true
  say "健康检查失败，回滚到 ${PREV_TAG:-旧版本}"
  cp -f "$BACKUP" "$ENVF"
  docker compose up -d || true
  die "已回滚"
fi

RUNNING_TAG="$(grep -E '^VM2API_IMAGE_TAG=' "$ENVF" | tail -1 | cut -d= -f2-)"
ok "升级成功 → $RUNNING_TAG"

# 备份：推到自己的 fork（rebase 改写过历史，必须 force-with-lease）
if git remote get-url mine >/dev/null 2>&1; then
  say "同步到远程备份"
  if git push -q --force-with-lease mine local 2>/dev/null; then
    ok "已推送 $(git rev-parse --short HEAD) → mine/local"
  else
    echo "  ⚠ push 失败（本地改动仍安全，可稍后手动 git push --force-with-lease mine local）"
  fi
fi

echo
echo "  回滚命令: sudo $SRC/scripts/rollback.sh"
echo "  查看改动: git log --oneline ${LATEST}..HEAD"
