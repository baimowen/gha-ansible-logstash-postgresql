# Role Name

安装并配置 podman，创建 `logging` 网络与 `pgdata` 卷，并通过
`containers.podman.podman_container` 部署 `postgresql`、`logstash` 两个容器。

## Requirements

- 目标主机使用 systemd（用于启用 `podman.socket`）
- 控制端需要 `containers.podman` collection：

```bash
ansible-galaxy collection install -r .ansible/requirements.yml
```

## Role Variables

见 `defaults/main.yml`，常用变量：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `podman_registry_mirrors` | `[]` | 镜像加速，见下方示例 |
| `podman_insecure_registries` | `[]` | 不安全注册表（`insecure = true`） |
| `podman_network_name` | `logging` | 容器网络名 |
| `postgresql_image` | `docker.io/library/postgres:16-alpine` | PostgreSQL 镜像 |
| `postgresql_publish` | `[]` | 映射到宿主机的端口，如 `["5432:5432"]` |
| `logstash_image` | `docker.elastic.co/logstash/logstash:8.17.0` | Logstash 镜像 |
| `logstash_pipeline_dir` | `/opt/logstash/pipeline` | pipeline 配置目录（只读挂载） |

镜像加速示例（`group_vars/all.yml`）：

```yaml
podman_registry_mirrors:
  - name: docker.io
    mirrors:
      - location: docker.m.daocloud.io
      - location: registry.cn-hangzhou.aliyuncs.com
```

## Dependencies

无。

## Example Playbook

```yaml
- hosts: all
  become: true
  roles:
    - role: podman
```

## License

MIT

## Author Information

rocky
