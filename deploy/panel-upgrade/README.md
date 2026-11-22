# 面板一键升级 → 宿主机脚本

链路：

面板 POST /api/panel/update {confirm:true}
  → 控制面写 /opt/vm2api/data/upgrade.request
  → systemd .path 单元触发 vm2api-panel-upgrade.service
  → /usr/local/bin/vm2api-panel-upgrade-hook
  → /opt/vm2api-src/scripts/upgrade.sh（rebase + 构建 + 冒烟 + 回滚 + 推送）
  → 状态写 /opt/vm2api/data/upgrade.status.json，面板 /api/panel/version 读取

安装：

    install -m 755 deploy/panel-upgrade/hook.sh /usr/local/bin/vm2api-panel-upgrade-hook
    install -m 644 deploy/panel-upgrade/vm2api-panel-upgrade.service /etc/systemd/system/
    install -m 644 deploy/panel-upgrade/vm2api-panel-upgrade.path /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable --now vm2api-panel-upgrade.path

日志：/var/log/vm2api-panel-upgrade.log
