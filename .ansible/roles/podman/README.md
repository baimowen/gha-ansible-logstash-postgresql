# Role Name

安装并配置 podman，创建 `logging` 网络与 `pgdata` 卷，
并通过 `containers.podman.podman_container` 部署 `postgresql`、`logstash` 以及 `filebeat` 容器。

## Requirements

- 目标主机使用 systemd（用于启用 `podman.socket`）
- 控制端需要 `containers.podman` collection：

```bash
ansible-galaxy collection install -r .ansible/requirements.yml
```

## Role Variables

镜像加速示例（`group_vars/all.yml`）：

```yaml
podman_registry_mirrors:
  - name: docker.io
    mirrors:
      - location: docker.m.daocloud.io
      - location: registry.cn-hangzhou.aliyuncs.com
```

## Dependencies

null

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

baimowen
