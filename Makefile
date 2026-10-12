.PHONY: lint lint-yaml lint-ansible lint-shell lint-action lint-compose

lint: lint-yaml lint-ansible lint-shell lint-action

lint-yaml: ## YAML 格式检查
	./scripts/lint.sh yaml

lint-ansible: ## Ansible 检查
	./scripts/lint.sh ansible

lint-shell: ## Shell 脚本检查
	./scripts/lint.sh shell

lint-action: ## GitHub Actions 检查
	./scripts/lint.sh action

lint-compose: ## Compose 文件语法验证
	./scripts/lint.sh compose
