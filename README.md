# gha-ansible-logstash-postgresql

通过 GitHub Actions 做 lint，通过 Ansible 在目标主机上部署 podman，并用
`podman_container` 部署 Logstash 与 PostgreSQL 容器。

## 结构

```
.github/workflows/ci.yaml   # CI：yamllint / ansible-lint / shellcheck / actionlint / compose 校验
docker-compose.yaml         # 等价的 compose 栈（本地开发与 CI 校验用）
logstash/pipeline/          # compose 使用的 logstash pipeline 配置
filebeat/filebeat.conf      # compose 使用的 filebeat 配置
.ansible/
├── playbooks/site.yaml     # 部署入口
├── requirements.yml        # containers.podman collection
└── roles/podman/           # 安装 podman + 部署 postgresql / logstash 容器
```

## 本地 lint

```bash
uv sync  # 安装 dev 依赖（yamllint / ansible-core / ansible-lint）
uv run yamllint -c .yamllint .
shellcheck scripts/*.sh
uv run ansible-galaxy collection install -r .ansible/requirements.yml
ANSIBLE_CONFIG=./.ansible/ansible.cfg uv run ansible-lint .
docker compose -f docker-compose.yaml config
```

## 用 compose 跑栈（本地）

```bash
cp .env.example .env   # 修改 POSTGRES_PASSWORD 等
docker compose up -d
```

## 用 Ansible 部署

```bash
export ANSIBLE_CONFIG=./.ansible/ansible.cfg
ansible-galaxy collection install -r .ansible/requirements.yml
ansible-playbook -i .ansible/inventory .ansible/playbooks/site.yaml
```

镜像加速配置在 `.ansible/group_vars/all.yml`：

```yaml
podman_registry_mirrors:
  - name: docker.io
    mirrors:
      - location: docker.m.daocloud.io
```

角色变量（镜像、端口、凭据等）见 `.ansible/roles/podman/defaults/main.yml`，
生产凭据请使用 ansible-vault 加密。

