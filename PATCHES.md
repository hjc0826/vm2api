# 补丁清单

本分支相对上游（`upstream` = dofastted/vm2api）的改动。升级 rebase 时按此核对。

当前基线：**v1.4.179**

---

## 1. 面板一键升级改走宿主机脚本

- 文件：`src/lib/admin/release.mjs`
- 改动：
  1. `upgradeCommand()` 返回 `sudo /opt/vm2api-src/scripts/upgrade.sh`
  2. `buildUpdateStatus().check_command` 返回 `... upgrade.sh --check`
  3. `startHostUpgrade()` 的 confirm 分支不再启动官方 `docker:27-cli` helper，
     改为写 `/opt/vm2api/data/upgrade.request`，返回 `202 {started:true, via:'host-script'}`
  4. `readHostUpgradeStatus()` 优先读 `/opt/vm2api/data/upgrade.status.json`
- 原因：官方一键升级会用官方 `docker-compose.yml` 拉 `ghcr.io/...` 镜像并改写
  `.env` 的 `VM2API_IMAGE_TAG`，覆盖本地构建，导致自维护分支失效。
- 逃生口：`VM2API_ALLOW_PANEL_UPGRADE=1` 恢复原生行为（不建议）。
- 上游检查点：`upgradeCommand()`、`buildUpdateStatus`、`startHostUpgrade`、
  `readHostUpgradeStatus`。

## 2. 宿主机执行器（新增文件，不改上游）

- `deploy/panel-upgrade/hook.sh` → `/usr/local/bin/vm2api-panel-upgrade-hook`
- `deploy/panel-upgrade/vm2api-panel-upgrade.service`
- `deploy/panel-upgrade/vm2api-panel-upgrade.path`（监听 `data/upgrade.request`）
- 日志：`/var/log/vm2api-panel-upgrade.log`
- 状态：`/opt/vm2api/data/upgrade.status.json`

## 3. 升级脚本本身

- `scripts/upgrade.sh`：拉上游 → rebase → 构建 → 备份 `.env` → 切换 → 冒烟 → 回滚 → 推送备份
- `scripts/rollback.sh`：恢复 `.env.upgrade-bak` 并重启
- `Makefile`、`FORK.md`、`PATCHES.md`

---

## 运维约定

| 场景 | 命令 |
|---|---|
| 面板点「升级」 | 自动执行（等同下一条） |
| 手动升级 | `sudo /opt/vm2api-src/scripts/upgrade.sh` |
| 只看有没有新版 | `scripts/upgrade.sh --check` |
| 同版本强制重建 | `scripts/upgrade.sh --rebuild` |
| 回滚 | `scripts/rollback.sh` |
| 看升级日志 | `tail -f /var/log/vm2api-panel-upgrade.log` |

- 镜像 tag：`local/vm2api:<上游版本>-p<提交数>`
- 远程备份：`mine` → `git@github-vm2api:hjc0826/vm2api.git`，升级成功后自动 `--force-with-lease` 推送
- 更新提醒：systemd timer 每日 01:00 UTC 检查，推送到 ntfy

---

## 待评估

### DMI / cpuinfo 覆盖挂载

- 状态：未实施，需先确认 `cli-node` 是否读取这两个路径
- 位置：`src/lib/vm/vm-runtime.mjs` 的 `computerDockerArgs()`
- 做法：新增两个 bind mount
  - `<persona>/system/dmi/id:/sys/class/dmi/id:ro`
  - `<persona>/system/cpuinfo:/proc/cpuinfo:ro`
- 前置验证：`docker exec <槽> strace -f -e trace=openat <cli-node>`
- 不可行项：`uname -r` 无法改（共享宿主内核）
