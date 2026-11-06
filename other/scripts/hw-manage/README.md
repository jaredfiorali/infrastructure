# Hardware Management — Fiorali Cluster

Per-node maintenance and version upgrades for the k3s cluster (5 RPi5 masters, 5 RPi4 workers).

## Layout

- `site.yml` — the playbook. Two stages, one node at a time (`serial: 1`):
  1. **k3s version status** (read-only): prints the latest k3s release once, then
     reports each node (up to date / out of date). Never changes anything.
  2. **apt maintenance**: `apt update`, `apt upgrade`, `autoremove`, `apt clean`.
- `maintenance.yml` — safely take a node out for a reboot, Longhorn-aware.
  Cordon → drain → reboot → validate Ready → uncordon, one node at a time
  (`serial: 1`), so k3s quorum and Longhorn replicas are never dropped at once.
- `upgrade-k3s.yml` — guardedly upgrade the k3s **version** on every node, one at a
  time. Drain + validate around the upgrade, quorum-safe ordering, with
  version-recorded rollback. See [Upgrading k3s](#upgrading-k3s).
- `inventory/hosts.yml` — inventory (the `k3s` group, per-node IPs/roles).
- `tasks/upgrade-node.yml` — shared per-node block (drain → k3sup → validate) used
  by `upgrade-k3s.yml`.
- `k3s-upgrade.lock` — git-tracked version record written by `upgrade-k3s.yml`
  (last-known-good version for rollback + whether the last run succeeded).
- `ansible.cfg` — SSH settings (`user=root`, disable host-key prompt).
- `requirements.txt` — pins `ansible-core`.

## Usage

```bash
# k3s version status + apt update/upgrade, one node at a time
ansible-playbook site.yml -i inventory/hosts.yml -b

# Reboot a node for maintenance, one at a time (Longhorn-aware)
ansible-playbook maintenance.yml -i inventory/hosts.yml

# Dry run (ansible --check) — see what would change without changing anything
ansible-playbook site.yml -i inventory/hosts.yml -b --check
```

## Upgrading k3s

`upgrade-k3s.yml` upgrades the k3s version across the whole cluster, **one node at
a time** (`serial: 1`), so you never drop k3s etcd quorum or all Longhorn replicas
at once. It masters before workers, upgrades the primary/initial server first, and
reuses the cluster's real upgrade path (`k3sup install`/`join` + the fixed
`--k3s-extra-args` set from `other/scripts/upgrade-k3s-cluster.sh`) so no custom
k3s-server flag is silently dropped.

For each node it:

1. **cordon** → **drain** → confirm the node is empty (no stranded workloads);
2. runs **k3sup** to apply the new version;
3. confirms no Longhorn volumes are still attached to the node, then waits for it
   to be **Ready**;
4. **uncordon**s it.

If anything fails on a node, that node is **rolled back** to the recorded
last-known-good version, uncordoned so it rejoins scheduling, and the play **stops**
— no other node is touched and the cluster is never left half-upgraded.

The run is three plays: a pre-flight that captures the current version as the
rollback baseline, the per-node serial upgrade, and a post-flight that records
success. `kubectl` and `k3sup` run from the operator's machine (localhost);
`become: false` overrides any `-b` on the CLI so nothing tries to sudo on the Mac.

```bash
# Upgrade every node to v1.38.0+k3s1
ansible-playbook upgrade-k3s.yml -i inventory/hosts.yml -e "upgrade_k3s_version=v1.38.0+k3s1"
```

Notes:

- Set the target version with `-e` on the CLI. Shell inline env assignment
  (`UPGRADE_K3S_VERSION=... ansible-playbook ...`) does **not** reach `lookup('env')`
  on this Ansible build.
- The target version must match `vX.Y.Z+k3sN` (e.g. `v1.38.0+k3s1`).
- The playbook refuses to run if the cluster is already on the target version.
- On success, `k3s-upgrade.lock` is updated with the new version and `status: success`.
  On failure it keeps the previous last-known-good version (no `status:` line).
- After fixing the cause, just re-run the same command — it re-probes, re-validates,
  and continues from where it stopped.

## Notes

- Master nodes are control-plane members; `site.yml` and `upgrade-k3s.yml` both run
  one node at a time (`serial: 1`) so an upgrade never drops the k3s quorum.
- `maintenance.yml` never upgrades k3s or manually scales anything — drain + ArgoCD
  handle the workloads, so there is no git commit and nothing to "scale back up".
