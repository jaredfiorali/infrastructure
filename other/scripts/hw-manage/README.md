# Hardware Management — Fiorali Cluster

## Quick Start

```bash
# Full maintenance (apt + firmware + k3s + Longhorn)
./hw-maintenance.sh

# With firmware upgrade
./hw-maintenance.sh --firmware

# With k3s upgrade (set version first)
K3S_VERSION=v1.30.0 ./hw-maintenance.sh --k3s

# Dry run
./hw-maintenance.sh --check
```

## Ansible Playbooks

- `site.yml` — full maintenance: apt, firmware, k3s (if requested)
- `reboot.yml` — reboot with Longhorn scale down/up
- `status.yml` — cluster health check

## Shell Scripts

- `hw-maintenance.sh` — unified maintenance (apt + firmware + k3s + Longhorn)
- `longhorn-reboot.sh` — Longhorn scale down / up
- `Makefile` — common targets

## Inventory

See `inventory/hosts.yml` — defines master/worker groups and node settings.

## Workflow

1. Apt upgrade (always)
2. Firmware check and notice (always)
3. Firmware upgrade (if `--firmware`)
4. k3s upgrade (if `--k3s`, requires `K3S_VERSION`)
5. Longhorn scale down (if k3s or firmware upgraded)
6. Reboot
7. Longhorn scale up (post-reboot)
