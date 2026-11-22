#!/bin/bash
# 面板「一键升级」的宿主机执行器。
# 面板写入 /opt/vm2api/data/upgrade.request，systemd .path 单元触发本脚本。
set -uo pipefail

REQ=/opt/vm2api/data/upgrade.request
STATUS=/opt/vm2api/data/upgrade.status.json
LOG=/var/log/vm2api-panel-upgrade.log
SCRIPT=/opt/vm2api-src/scripts/upgrade.sh

exec 9>/run/vm2api-panel-upgrade.lock
flock -n 9 || exit 0
[ -f "$REQ" ] || exit 0

TARGET="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("target",""))' "$REQ" 2>/dev/null || true)"
CUR="v$(tr -d '[:space:]' </opt/vm2api/VERSION 2>/dev/null)"

# 目标就是当前版本时（用户重复点击），做一次强制重建以验证流程
MODE=""
if [ -n "$TARGET" ] && [ "$TARGET" = "$CUR" ]; then
  MODE="--rebuild"
fi

mv -f "$REQ" "$REQ.processing"
START="$(date -Is)"
printf '{"state":"running","target":"%s","started_at":"%s","log_command":"tail -f %s"}\n' \
  "$TARGET" "$START" "$LOG" > "$STATUS"

{
  echo "=== $(date -Is) panel-triggered upgrade target=$TARGET mode=${MODE:-upgrade} ==="
  if [ -n "$MODE" ]; then "$SCRIPT" "$MODE"; else "$SCRIPT"; fi
} >>"$LOG" 2>&1
RC=$?

if [ "$RC" -eq 0 ]; then
  printf '{"state":"succeeded","target":"%s","started_at":"%s","finished_at":"%s","exit_code":0,"log_command":"tail -f %s"}\n' \
    "$TARGET" "$START" "$(date -Is)" "$LOG" > "$STATUS"
else
  printf '{"state":"failed","target":"%s","started_at":"%s","finished_at":"%s","exit_code":%s,"log_command":"tail -f %s"}\n' \
    "$TARGET" "$START" "$(date -Is)" "$RC" "$LOG" > "$STATUS"
fi

rm -f "$REQ.processing"
exit 0
