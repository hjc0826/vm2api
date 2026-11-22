# vm2api 自维护分支

服务器上跑的是**自己构建的镜像**，不是官方 ghcr 镜像。
升级由脚本完成，失败自动回滚。

## 你只需要记一个命令

```bash
sudo /opt/vm2api-src/scripts/upgrade.sh
```

它会依次做：

1. 确认工作区干净（有未提交改动就停下）
2. 拉上游 tag，告诉你当前版本和最新版本
3. 把你的提交 rebase 到新版上（冲突会停下来提示）
4. 构建镜像，tag 形如 `1.4.180-p3`（p3 = 你的第 3 个提交）
5. 备份 `.env`，切换容器
6. 健康检查；失败自动回滚到旧镜像

## 其它命令

```bash
scripts/upgrade.sh --check   # 只看有没有新版，不动任何东西
scripts/rollback.sh          # 手动回滚到上一次升级前
make build                   # 只构建，不切换
make smoke                   # 健康检查
make patches                 # 列出你相对上游的改动
```

## 目录约定

| 路径 | 作用 |
|---|---|
| `/opt/vm2api-src` | 源码 + 你的提交（本仓库） |
| `/opt/vm2api` | 运行目录（`.env`、`data/`、`vms/`、`src/config/`） |
| `upstream` 远程 | 官方仓库，只读 |
| `local` 分支 | 你的改动所在分支 |

## 什么会被升级换掉、什么不会

| | 换掉 | 保留 |
|---|---|---|
| 程序代码 | ✅ 新镜像 | — |
| `.env` | 保留（升级前备份） | ✅ |
| `data/`（数据库、日志） | — | ✅ |
| `vms/`（槽位、凭据） | — | ✅ |
| `src/config/`（routing.json） | — | ✅ |
| `bin/` `share/` | — | ✅ |

## 加一个新改动

```bash
cd /opt/vm2api-src
# 改代码
git add -A && git commit -m "feat: 说明这个改动干什么"
sudo scripts/upgrade.sh      # 或 make build && make up
```

规则：

- **一个改动一个 commit**，便于 rebase 时定位冲突
- 能在 `routing.json` / `.env` / nginx 里解决的，不要改代码
- 不要改 `/opt/vm2api/docker-compose.yml`（升级会覆盖）

## 出问题怎么查

```bash
docker logs --tail 80 vm2api        # 控制面日志
docker ps -a --filter name=vm2api   # 容器状态
scripts/rollback.sh                 # 回到旧镜像
```

## 补丁清单

见 `PATCHES.md`。
