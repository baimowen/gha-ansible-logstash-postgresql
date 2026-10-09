# gha-ansible-logstash-postgresql

通过 GitHub Actions 做 lint，通过 Ansible 在目标主机上部署 podman，
并用 `podman_container` 部署 Filebeat、Logstash、PostgreSQL容器。

## 目录结构

```
.github/workflows/ci.yaml           # CI：yamllint / ansible-lint / shellcheck / actionlint / compose 校验
.ansible/
├── playbooks/site.yaml             # 部署入口
├── requirements.yml                # containers.podman collection
└── roles/podman/                   # 安装 podman + 部署 postgresql / logstash / filebeat 容器
docker-compose.yaml                 # 等价的 compose 栈（本地开发与 CI 校验用）
compose/
├──logstash/pipeline/logstash.conf  # compose 使用的 logstash pipeline 配置
└──filebeat/filebeat.conf           # compose 使用的 filebeat 配置
scripts/generation_inventory.sh     # 根据局域网扫描生成主机清单
```

## 本地 lint

```bash
source .venv/bin/activate
mkdir -p src/gha_ansible_logstash_postgresql
touch $_/__init__.py
uv sync
shellcheck scripts/*.sh
uv run yamllint -c .yamllint .
uv run ansible-galaxy collection install -r .ansible/requirements.yml
ANSIBLE_CONFIG=./.ansible/ansible.cfg uv run ansible-lint .
```

## 用 Ansible 部署

```bash
cp .envrc.template .envrc
direnv allow ./.envrc
# or use
# export ANSIBLE_CONFIG=./.ansible/ansible.cfg
ansible-galaxy collection install -r .ansible/requirements.yml
ansible-playbook -i .ansible/inventory .ansible/playbooks/site.yaml --tags setup -bK
mkdir -p ./var/log
ansible-playbook -i .ansible/inventory .ansible/playbooks/site.yaml --tags deploy
```

镜像加速配置在 `.ansible/group_vars/all.yml`：

```yaml
podman_registry_mirrors:
  - name: docker.io
    mirrors:
      - location: docker.m.daocloud.io
```

角色变量（镜像、端口、凭据等）见 `.ansible/roles/<role_name>/defaults/main.yml`，
生产凭据请使用 ansible-vault 加密。

## 用 compose 部署（本地）

```bash
cp .env.example .env   # 修改 POSTGRES_PASSWORD 等
docker compose up -d
```

