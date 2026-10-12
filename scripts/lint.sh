#!/usr/bin/env bash
set -euo pipefail

LINT_TARGET="${1:-all}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
export ANSIBLE_CONFIG=./.ansible/ansible.cfg

FAILED=()
ENV_SKIP=0

# 独立环境检查：命令全部可用返回 0；否则置跳过标记、警告并返回 1
check_env() {
    local cmd missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    [ ${#missing[@]} -eq 0 ] && return 0
    ENV_SKIP=1
    echo "[warn] 环境不完整，缺少命令: ${missing[*]}，跳过"
    return 1
}

run_lint() {
    local name="$1"
    local func="$2"
    echo "--- lint: $name ---"
    ENV_SKIP=0
    if $func; then
        if [ "$ENV_SKIP" -eq 1 ]; then
            echo "[skip] $name"
        else
            echo "[ok] $name"
        fi
    else
        echo "[fail] $name"
        FAILED+=("$name")
    fi
}

lint_yaml() {
    check_env yamllint || return 0
    yamllint -c .yamllint .
}

lint_ansible() {
    check_env ansible-lint || return 0
    ansible-lint .
}

lint_shell() {
    check_env shellcheck || return 0
    shellcheck scripts/*.sh
}

lint_action() {
    if ! check_env actionlint; then
        echo "  安装: https://github.com/rhysd/actionlint#installation"
        return 0
    fi
    local rc=0 f
    for f in .github/workflows/*.yaml .github/workflows/*.yml; do
        [ -f "$f" ] || continue
        actionlint - < "$f" || rc=1
    done
    return $rc
}

lint_compose() {
    check_env docker || return 0
    if [ ! -f .env ] && [ -z "${POSTGRES_PASSWORD:-}" ]; then
        ENV_SKIP=1
        echo "[warn] .env 不存在且 POSTGRES_PASSWORD 未设置，跳过 compose 校验"
        echo "  请执行: cp .env.example .env 并修改"
        return 0
    fi
    docker compose -f docker-compose.yaml config --quiet
}

case "$LINT_TARGET" in
    yaml)    run_lint "yaml"    lint_yaml ;;
    ansible) run_lint "ansible" lint_ansible ;;
    shell)   run_lint "shell"   lint_shell ;;
    action)  run_lint "action"  lint_action ;;
    compose) run_lint "compose" lint_compose ;;
    all)
        run_lint "yaml"    lint_yaml
        run_lint "ansible" lint_ansible
        run_lint "shell"   lint_shell
        run_lint "action"  lint_action
        ;;
    *) echo "Usage: $0 {yaml|ansible|shell|action|compose|all}"; exit 1 ;;
esac

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "=== 失败: ${FAILED[*]} ==="
    exit 1
fi
echo "=== 全部通过 ==="
