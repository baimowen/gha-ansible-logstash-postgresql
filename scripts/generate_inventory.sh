#!/usr/bin/env bash
set -euo pipefail

SSH_PORT=22
ANSIBLE_CONFIG_DIR="${1:-./.ansible}"
INVENTORY="${ANSIBLE_CONFIG_DIR%/}/inventory"
INTERFACE=$(ip -o -4 route show default | awk '{print $5}' | head -n1)
IPADDR=$(ip -o -4 addr show "$INTERFACE" | awk '{print $4}' | cut -d/ -f1)
NETWORK=$(ip -o -4 route show dev "$INTERFACE" proto kernel scope link | awk '{print $1}')

mkdir -p "${ANSIBLE_CONFIG_DIR}"

RAW_HOSTS=$(sudo nmap -Pn -p"${SSH_PORT}" -n "${NETWORK}" --open -oG - | awk '/22\/open/{print $2}')
[[ -z "$RAW_HOSTS" ]] && { echo "[warn] no host with open ${SSH_PORT} found" >&2; exit 0; }

GROUP="all"
[[ ! -f "$INVENTORY" ]] && echo "[${GROUP}]" > "$INVENTORY"

# exists inventory and localhost ipaddr
EXISTING=$(
  sed -n "/^\[${GROUP}\]/,/^\[/{/^\[/d;p}" "$INVENTORY"
  printf '%s\n' "$IPADDR"
)

# exclude EXISTING and duplicates in the scan
CLEAR_HOSTS=$(
  printf '%s\n' "$RAW_HOSTS" \
    | awk 'NF' \
    | sort -u \
    | grep -vxF -f <(printf '%s\n' "$EXISTING") || true
)
[[ -z "$CLEAR_HOSTS" ]] && { echo "[info] no new host to add" >&2; exit 0; }

# append line by line to the host group: [all]
while IFS= read -r -d '' host; do
  sed -i "/\[${GROUP}\]/a ${host}" "$INVENTORY"
done < <(printf "%s\n" "$CLEAR_HOSTS" | tr '\n' '\0')
