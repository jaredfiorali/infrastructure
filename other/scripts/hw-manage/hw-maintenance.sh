#!/usr/bin/env bash
# Full hardware maintenance via Ansible on the k3s cluster.
#
# Usage: hw-maintenance.sh [--firmware] [--k3s] [--check] [--verbose]
#
# --firmware   Perform firmware upgrade (rpi-update)
# --k3s        Perform k3s upgrade (requires K3S_VERSION env var)
# --check      Dry run (ansible --check)
# --verbose    Run ansible with -v

set -euo pipefail

cd "$(dirname "$0")"

FIRMWARE=0
K3S=0
CHECK=0
VERBOSE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --firmware) FIRMWARE=1; shift ;;
    --k3s)      K3S=1; shift ;;
    --check)    CHECK=1; shift ;;
    --verbose)  VERBOSE="-v"; shift ;;
    *)          shift ;;
  esac
done

# Build extra-vars for ansible
EVAR="--extra-vars 'scale_longhorn=true'"
[[ $FIRMWARE -eq 1 ]] && EVAR="${EVAR} firmware_upgrade=true"
[[ $K3S -eq 1 ]] &&      EVAR="${EVAR} k3s_upgrade=true"
[[ $CHECK -eq 1 ]] &&    EVAR="${EVAR} check_only=true"
[[ -n "${K3S_VERSION:-}" ]] && EVAR="${EVAR} k3s_version=${K3S_VERSION}"

echo "─── hw-maintenance (Ansible on k3s group) ───"

echo ""
echo "→ Running site.yml (apt + firmware + k3s)..."
ansible-playbook site.yml -i inventory/hosts.yml -b $EVAR $VERBOSE

echo ""
echo "→ Running reboot.yml (scale down Longhorn → reboot → scale up)..."
ansible-playbook reboot.yml -i inventory/hosts.yml -b --extra-vars "scale_longhorn=true $EVAR" $VERBOSE

echo ""
echo "─── Maintenance complete. ───"
