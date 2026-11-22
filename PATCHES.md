# 补丁清单

本分支相对上游（`upstream` = dofastted/vm2api）的改动。升级 rebase 时按此核对。

当前基线：**v1.4.179**

---

## 1. 面板一键升级改为自维护脚本

- 文件：`src/lib/admin/release.mjs`
- 目的：面板展示的升级命令指向 `/opt/vm2api-src/scripts/upgrade.sh`；
  `POST /api/panel/update`（一键升级）返回 `409 host_upgrade_disabled`。
- 原因：官方一键升级会用官方 `docker-compose.yml` 拉 `ghcr.io/...` 镜像并改写
  `.env` 的 `VM2API_IMAGE_TAG`，覆盖本地构建的镜像，导致自维护分支失效。
- 逃生口：设置环境变量 `VM2API_ALLOW_PANEL_UPGRADE=1` 可恢复原生行为（不建议）。
- 上游检查点：`upgradeCommand()`、`buildUpdateStatus().check_command`、
  `startHostUpgrade()` 里 `const command = upgradeCommand(target)` 之后的位置。

## 2. 升级脚本 scaffolds（非上游代码）

- `scripts/upgrade.sh`：拉上游 → rebase → 构建 → 备份 `.env` → 切换 → 冒烟 → 回滚 → 推送备份
- `scripts/rollback.sh`：恢复 `.env.upgrade-bak` 并重启
- `Makefile`、`FORK.md`、`PATCHES.md`

## 运维约定

- 升级：`sudo /opt/vm2api-src/scripts/upgrade.sh`
- 预览：`scripts/upgrade.sh --check`
- 回滚：`scripts/rollback.sh`
- 同版本强制重建：`scripts/upgrade.sh --rebuild`
- 镜像 tag：`local/vm2api:<上游版本>-p<提交数>`
- 远程备份：`mine` → `git@github-vm2api:hjc0826/vm2api.git`，升级成功后自动 `--force-with-lease` 推送

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
