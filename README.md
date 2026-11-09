# gha-ansible-logstash-postgresql

基于 **GitHub Actions + Ansible + HashiCorp Vault** 的日志平台部署示例，数据链路为
**Filebeat → Logstash → Elasticsearch → Kibana**。支持 Podman 容器化部署与 Elastic RPM 包安装两种方式。

## 目录

- [项目特点](##项目特点)
- [目录结构](##目录结构)
- [环境准备](##环境准备)
- [目标主机与主机清单](##目标主机与主机清单)
- [Vault 与凭据管理](##vault-与凭据管理)
- [Lint 与 CI](##lint-与-ci)
- [Ansible 部署](##ansible-部署)
- [docker-compose 方式](##docker-compose-方式)
- [配置参考](##配置参考)

## 项目特点

- **CI 质量检查**：`yamllint`、`ansible-lint`、`shellcheck`、`actionlint`、`docker compose config`。
- **密钥集中管理**：敏感变量存放在 HashiCorp Vault，Ansible 在运行时读取，不写入仓库。
- **容器化部署**：通过 `containers.podman` 部署 Elasticsearch、Kibana、Logstash、Filebeat。
- **包安装部署**：通过 Elastic YUM 源安装 Elasticsearch、Kibana、Logstash。
- **可复现开发环境**：提供 `uv` 与 Nix/devenv 两种环境入口。
- **主机发现辅助**：`scripts/generate_inventory.sh` 可扫描局域网内开放 SSH 的主机并写入清单。

## 目录结构

```text
.
├── .github/workflows/ci.yaml          # CI：lint 与 compose 校验
├── .ansible/
│   ├── ansible.cfg                    # Ansible 全局配置（inventory/roles/collections/SSH）
│   ├── inventory                      # 主机清单，默认包含 dest_host
│   ├── group_vars/all                 # 全局变量
│   ├── host_vars/                     # 主机变量，文件名需与 inventory 主机名一致
│   ├── requirements.yml               # Galaxy roles / collections 依赖
│   ├── playbooks/site.yaml            # 部署入口，通过 tags 选择任务
│   └── roles/
│       ├── podman/                    # 容器化部署：ES / Kibana / Logstash / Filebeat
│       ├── elastic_repo/              # Elastic YUM 仓库与 GPG Key
│       ├── elasticsearch/             # Elasticsearch 包安装方式
│       ├── kibana/                    # Kibana 包安装方式
│       └── logstash/                  # Logstash 包安装方式
├── Makefile                           # lint 入口
├── scripts/lint.sh                    # 各类 lint 的具体实现
├── var/log/messages                   # 本地测试日志样例
├── devenv.nix / devenv.yaml           # Nix + devenv 开发环境
├── flake.nix / flake.lock             # Nix flake
├── pyproject.toml / uv.lock           # Python 与 lint 依赖
├── docker-compose.yaml                # 本地 compose 服务定义
├── .envrc                             # 用于 direnv 挂载环境
└── .vault-token                       # 临时 vault 服务根令牌
```

## 环境准备

### 支持平台

- **目标主机**：Rocky Linux / RHEL 9。
- **控制端**：Linux、Python 3.11+、Ansible Core 2.17–2.19。

### 方式一：uv + direnv

手动同步 python 第三方库以及安装 ansible galaxy

```shell
uv sync --group lint
direnv allow ./.envrc
mkdir -p ./var/log
echo "then: $(date -Isecond)" > ./var/log/messages
ansible-galaxy role install -r .ansible/requirements.yml -p .ansible/roles/
ansible-galaxy collection install -r .ansible/requirements.yml
```

### 方式二：Nix + devenv

devenv 会自动安装 Python、uv、Ansible、actionlint、`gh`、`act`、`jq` 等工具，并在进入 shell 时安装 Galaxy 依赖。

```shell
cat <<EOF | sudo tee -a /etc/nix/nix.conf
extra-trusted-substituters = https://nixpkgs-python.cachix.org
extra-trusted-public-keys = nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU=
extra-substituters = https://nixpkgs-python.cachix.org
EOF
sudo systemctl daemon-reload
sudo systemctl restart nix-daemon
nix develop --no-pure-eval
```

## 目标主机与主机清单

默认清单文件为 `.ansible/inventory`：

```ini
[all]
dest_host
```

>  需提前在本地hosts文件内配置dns解析，或直接修改为目标主机ip

主机变量放在 `.ansible/host_vars/<主机名>`。**文件名必须与 inventory 中的主机名一致**

如需扫描局域网主机写入主机清单，可执行：

```shell
./scripts/generate_inventory.sh
```

## Vault 与凭据管理

Ansible 部署前需要可用的 Vault 服务

### 临时开发服务

无需解密和登录，但服务重启后数据会丢失：

```shell
echo 'your-vault-token' > .vault-token
# 生产环境不要使用 -dev
vault server -dev -dev-root-token-id "$(cat .vault-token)" -dev-listen-address="127.0.0.1:8200" &
```

### 持久化服务

需手动解密和登录

```shell
devenv up -d  # 启动 services.vault
vault operator unseal   # 输入 devenv up 输出的 unseal key
vault login             # 输入 devenv up 输出的 root token
vault secrets enable -path=secret kv-v2  # 创建 vault 密钥 api 路径
```

### 写入敏感数据

```shell
mkdir -p secrets
jq -n '{es: {_vault_elasticsearch_password: "password"}}' > secrets/vault_password.json

vault kv put -mount=secret es \
  es_pass="$(jq -r '.es._vault_elasticsearch_password' secrets/vault_password.json)"

vault kv get -mount=secret es
```

验证 Ansible 读取该密钥：

```shell
uv run ansible localhost -bKm community.hashi_vault.vault_read \
  -a "url=http://127.0.0.1:8200 token=your-vault-token path=secret/data/es" \
  -c local | awk '
    /BECOME password:/ { next }
    /=> *\{/           { print "{"; f=1; next }
    f && /^\}/         { print "}"; exit }
    f                  { print }' \
  | jq .data.data.data
# output: _vault_elasticsearch_password: password
```

>  不要通过 role 变量或者组变量或者 `-e` 传递敏感数据，而应始终使用 `.secrets` 或 vault 存储你的密码

## Lint 与 CI

本地检查：

```shell
make lint          # yaml + ansible + shell + action
make lint-yaml
make lint-ansible
make lint-shell
make lint-action
make lint-compose  # 单独执行，需要 docker
```

也可以直接调用：

```shell
./scripts/lint.sh all
```

CI 工作流 `.github/workflows/ci.yaml` 在 push、pull request 和手动触发时运行：

1. 安装 Python、uv 与 lint 依赖；
2. 安装 Ansible collections / roles；
3. 安装 `actionlint`、`shellcheck`；
4. 依次执行 shell、YAML、workflow、Ansible 检查；
5. 校验 `docker-compose.yaml` 语法。

## Ansible 部署

剧本入口为 `.ansible/playbooks/site.yaml`，通过 tags 选择执行阶段。
执行前请确认已进入项目环境，使 `ANSIBLE_CONFIG=./.ansible/ansible.cfg` 生效：

| Tag | 目标主机 | 作用 |
| --- | --- | --- |
| `deploy-vault` | `127.0.0.1` | 安装 Vault，并从 `secret/es` 读取密码写入 `.secrets` |
| `create-user` | 清单主机 | 创建 `ansible` 用户、配置 SSH Key 与免密 sudo |
| `deploy-container` | 清单主机 | 使用 Podman 部署完整日志栈 |
| `deploy-pkgs` | 清单主机 | 配置 Elastic YUM 源并安装 Elasticsearch / Kibana / Logstash |

```shell
# 1. 本地安装 Vault 并准备 .secrets
ansible-playbook -i .ansible/inventory .ansible/playbooks/site.yaml \
  --tags deploy-vault -bK

# 2. 在目标主机创建部署用户
ansible-playbook -i .ansible/inventory .ansible/playbooks/site.yaml \
  --tags create-user -bK

# 3. 容器化部署或通过包管理部署
ansible-playbook -i .ansible/inventory .ansible/playbooks/site.yaml \
  --tags deploy-container
ansible-playbook -i .ansible/inventory .ansible/playbooks/site.yaml \
  --tags deploy-pkgs
```

### 容器化部署

`deploy-container` 会完成：

1. 安装 Podman 并启用 `podman.socket`；
2. 可选配置镜像加速（`podman_registry_mirrors`）；
3. 创建 `logging` 网络与 `esdata` 数据卷；
4. 设置 `vm.max_map_count=262144`；
5. 渲染配置并启动 Elasticsearch、Kibana、Logstash、Filebeat；
6. 初始化/校正 Elasticsearch 与 `kibana_system` 密码；
7. 将目标主机 `/tmp/logging` 只读挂载到 Filebeat 容器的 `/var/log`。

| 组件 | 容器名 | 默认端口 | 说明 |
| --- | --- | --- | --- |
| Filebeat | `filebeat` | - | 采集 `/var/log/messages` 与 Nginx 日志，发送到 Logstash |
| Logstash | `logstash` | `5044` / `9600` | 接收 Beats 事件并写入 Elasticsearch |
| Elasticsearch | `elasticsearch` | `9200` | 单节点模式，启用基础认证 |
| Kibana | `kibana` | `5601` | 可视化入口 |

容器统一接入 Podman 网络 `logging`，Elasticsearch 数据保存在名为 `esdata` 的卷中。

验证容器状态（在目标主机执行）：

```shell
podman ps
curl -u elastic:"$(vault kv get -field=es_pass -mount=secret es)" \
  http://127.0.0.1:9200/_cluster/health
```

### 通过包管理部署

`deploy-pkgs` 依次执行：

- `elastic_repo`：导入 GPG Key 并配置 `elastic-<major>.x` YUM 源；
- `elasticsearch`：安装对应版本的 Elasticsearch RPM；
- `kibana`：安装对应版本的 Kibana RPM；
- `logstash`：安装对应版本的 Logstash RPM。

>  当前该方式尚未完成，等待后续补齐

## docker-compose 方式

该方式作用对象为本地容器而非目标主机容器

```shell
cp .env.example .env
docker compose up -d
```

## 配置参考

- **Ansible 全局变量**：`.ansible/group_vars/all`
- **Podman 角色变量**：`.ansible/roles/podman/defaults/main.yml`
- **Elastic YUM 源变量**：`.ansible/roles/elastic_repo/defaults/main.yml`。
- **包版本变量**：各包角色 `defaults/main.yml` 中的 `*_version` / `*_package`。
- **镜像加速**：`.ansible/roles/podman/defaults/main.yml` 中的 `podman_registry_mirrors`。

示例：调整 Elastic Stack 版本：

```yaml
# .ansible/group_vars/all
elastic_stack_version: "9.5.6"
```

示例：调整镜像加速地址：

```yaml
podman_registry_mirrors:
  - name: docker.io
    mirrors:
      - location: docker.m.daocloud.io
```
