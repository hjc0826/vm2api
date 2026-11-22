SRC := /opt/vm2api-src
DEPLOY := /opt/vm2api

.PHONY: help upgrade check rollback build up smoke patches log

help:
	@echo "make upgrade   # 拉上游 + rebase + 构建 + 切换 + 冒烟（失败回滚）"
	@echo "make check     # 只看上游有没有新版"
	@echo "make rollback  # 回到上一次升级前的镜像"
	@echo "make build     # 只构建当前代码，不切换"
	@echo "make up        # 用当前 .env 重启容器"
	@echo "make smoke     # 健康检查"
	@echo "make patches   # 列出你相对上游的改动"
	@echo "make log       # 看控制面日志"

upgrade:
	@sudo $(SRC)/scripts/upgrade.sh

check:
	@$(SRC)/scripts/upgrade.sh --check

rollback:
	@sudo $(SRC)/scripts/rollback.sh

build:
	@cd $(SRC) && \
	 ver=$$(git describe --tags --abbrev=0) && \
	 n=$$(git rev-list --count $$ver..HEAD) && \
	 VM2API_IMAGE=local/vm2api VM2API_IMAGE_TAG=$${ver#v}-p$$n \
	 docker compose -f docker-compose.yml -f docker-compose.build.yml build

up:
	@cd $(DEPLOY) && sudo docker compose up -d

smoke:
	@curl -fsS --noproxy '*' http://127.0.0.1:8787/health >/dev/null && echo "health ok"

patches:
	@cd $(SRC) && git log --oneline $$(git describe --tags --abbrev=0)..HEAD

log:
	@docker logs --tail 80 -f vm2api
