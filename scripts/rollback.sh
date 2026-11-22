#!/usr/bin/env bash
# 回滚到上一次升级前的镜像
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY="${VM2API_DEPLOY_DIR:-/opt/vm2api}"
ENVF="$DEPLOY/.env"
BACKUP="$DEPLOY/.env.upgrade-bak"

ok()  { printf '\033[32m✓\033[0m %s\n' "$*"; }
die() { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

[ -f "$BACKUP" ] || die "没有可用的备份 $BACKUP"

echo "回滚前的配置:"
grep -E '^VM2API_IMAGE(_TAG)?=' "$ENVF" || true
echo "将恢复到:"
grep -E '^VM2API_IMAGE(_TAG)?=' "$BACKUP" || true

cp -f "$BACKUP" "$ENVF"
cd "$DEPLOY"
docker compose up -d

for i in $(seq 1 45); do
  if curl -fsS --noproxy '*' -o /dev/null http://127.0.0.1:8787/health 2>/dev/null; then
    ok "已回滚并通过健康检查"
    exit 0
  fi
  sleep 2
done

die "回滚后健康检查失败，看日志: docker logs --tail 60 vm2api"
