# gha-ansible-logstash-postgresql

通过 GitHub Actions 做 lint，通过 Ansible 部署 filebeat-logstash-postgresql 从采集、分析到入库流程。

## 目录结构

```
.github/workflows/ci.yaml           # CI：yamllint / ansible-lint / shellcheck / actionlint / compose 校验
.ansible/
├── playbooks/site.yaml             # 剧本入口，通过指定不同标签按方案部署
├── roles/podman/                   # 容器化部署方案 podman + 部署 postgresql / logstash / filebeat  容器
└── requirements.yml                # ansible 所需 role 和 collection
.vault-token                        # 用于 hashicorp vault 登录
docker-compose.yaml                 # 与容器化部署方案等价的 compose 栈
compose/
├──logstash/pipeline/logstash.conf  # compose 使用的 logstash pipeline 配置
└──filebeat/filebeat.conf           # compose 使用的 filebeat 配置
Makefile                            # 项目入口，包含 make lint/build/release 等
scripts/*                           # 包含 lint 、build 、release 流程的脚本
```

## 主机清单

`dest_host` 主机需提前在本地hosts文件内配置dns解析，或直接修改为目标主机ip，并重命名主机变量 `.ansible/host_vars/dest_host`

## 本地环境准备

```shell
uv sync
direnv allow ./.envrc
mkdir -p ./var/log
ansible-galaxy role install -r .ansible/requirements.yml -r .ansilbe/roles/
ansible-galaxy collection install -r .ansible/requirements.yml
```

后续若无特别声明，均默认以该环境为运行基准

### 凭据和变量

镜像加速配置在 `.ansible/roles/podman/default/main.yml:12`：

```yaml
podman_registry_mirrors:
  - name: docker.io
    mirrors:
      - location: docker.m.daocloud.io
```

角色变量（镜像、端口、凭据等）见 `.ansible/roles/<role_name>/defaults/main.yml`，

敏感数据由 hashicorp vault 存储，ansible 和 compose 两种方式部署均从该处获取值，
通过 put 命令存入数据库密码，根据需要自定义添加更多

```shell
echo 'your-vault-token' > .vault-token
vault secrets enable -path=kv kv-v2
vault server -dev -dev-root-token-id $(cat .vault-token) -dev-listen-address="127.0.0.1:8200" &
mkdir secrets
cat <<EOF > secrets/vault_password.json
{"_vault_postgresql_password":"password"}
EOF
vault kv put -mount=kv postgresql @secrets/vault_data.json
# test reading secrets from hashi vault
uv run ansible localhost -bKm community.hashi_vault.vault_read \
  -a "url=http://127.0.0.1:8200 token=root path=kv/data/postgresql" \
  -c local | awk '
    /BECOME password:/ { next }
    /=> *\{/           { print "{"; f=1; next }
    f && /^\}/         { print "}"; exit }
    f                  { print }' \
  | jq .data.data.data 
```

### lint

```bash
shellcheck scripts/*.sh
yamllint -c .yamllint .
ansible-lint .  # requires: collections and roles have been installed
```

## Ansible 方式

## 预处理

```bash
ansible-playbook -i .ansible/inventory .ansible/playbooks/site.yaml --tags deploy-vault -bK  # dest host is 127.0.0.1
ansible-playbook -i .ansible/inventory .ansible/playbooks/site.yaml --tags create-user -bK
```

### 包管理部署

等待后续补齐

### 容器化部署

```bash
ansible-playbook -i .ansible/inventory .ansible/playbooks/site.yaml --tags deploy
```

## docker-compose 方式

```bash
cp .env.example .env
podman compose up -d  # docker 同样使用 compose 命令
```

