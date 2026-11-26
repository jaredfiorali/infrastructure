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
- `power-down.yml` — power down the **whole** cluster (e.g. to upgrade the network
  switch), canary-first. Reboot one node first (the primary server by default, since
  it holds etcd quorum) and confirm it returns before shutting everything down;
  workers go down first, servers last. It is a separate file from `maintenance.yml`
  because its end-state is "everything off", not "cluster still running".
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

# Power down the whole cluster for switch/firmware work — reboot one node first
# (the primary server), confirm it returns, then shut everything down (workers
# first, servers last). Press Enter at the prompt to continue, Ctrl+C to abort.
ansible-playbook power-down.yml -i inventory/hosts.yml

# Skip the confirmation prompt (automation), or pick a different canary node:
POWER_DOWN_AUTO=1 ansible-playbook power-down.yml -i inventory/hosts.yml
ansible-playbook power-down.yml -i inventory/hosts.yml -e canary_host=rpi4-node-2

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
3. confirms every Longhorn volume on the node is `Detached` (fails the node if any
   is still attached or mid-migration), then waits for it to be **Ready**;
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

## Powering down the cluster

`power-down.yml` takes the **entire** cluster offline — for example to upgrade the
network switch the nodes plug into. It is canary-first: before trusting that
everything will come back, it cycles one node and confirms it rejoins the cluster.

The run is five plays:

1. **Canary** — cordon → drain → reboot one node → wait for it to be **Ready** →
   uncordon. The canary is the primary server by default (`rpi5-node-3`, the node
   marked `k3s_server: true`, which holds etcd quorum) — the safest node to test
   first. If it does not come back, the playbook **stops** and nothing else is shut
   down; the problem is the node or its link, not the switch. Override with
   `-e canary_host=<hostname>`.
2. **Scale down** — scales every Longhorn-backed workload to **0 replicas** by
   patching its Argo Application's inline `helm.values.replicaCount` to `0`. An inline
   value overrides the git valueFile, so it survives Argo's continuous sync / drift
   detection, and the Deployment dropping to 0 replicas is what cleanly detaches the
   Longhorn volume (the official detach method). Run from your machine; see
   "Detaching Longhorn volumes cleanly" below.
3. **Confirm** — waits until every Longhorn volume reports state **detached** (the
   playbook aborts if any stays attached), then a single prompt (on your machine) to
   abort before the irreversible step. Press Enter to continue, Ctrl+C to stop, or set
   `POWER_DOWN_AUTO=1` to skip.
4. **Workers** — power off every worker. Workers hold no quorum, so this never
   threatens the cluster.
5. **Servers** — power off every server, one at a time, **last**, keeping etcd
   quorum alive until the very end so the cluster stays manageable right up to the
   final node.

Why separate worker and server plays? A single `hosts: [...]` list does not preserve
group order, so two plays are the only reliable way to guarantee workers go down
before servers.

Each node is powered off with a graceful `shutdown -h now`, which lets systemd stop
k3s cleanly (graceful etcd shutdown) before the power drops. The plays deliberately
do **not** cordon/drain: with every node going down there is nowhere to move
workloads, so the kubelet terminates pods during the graceful shutdown instead.

### Detaching Longhorn volumes cleanly

Cordon/drain detaches Longhorn volumes by moving their workloads to a *healthy* node —
but in a full shutdown there is nowhere healthy to move them, so that trick does not
apply. Instead, the playbook detaches them by **scaling the workloads to 0**:

1. **The apps are labelled** `longhorn-pv=true` on their Argo Application
   (`kubectl get applications -A -l longhorn-pv=true`). That now covers all nine
   Longhorn-backed apps, including `postgres` and `romm` (which were missing the label
   and have been added to `applications/`). Play 2 scales exactly these apps down.
2. **Play 2 patches each app's inline** `helm.values.replicaCount: 0`. This is
   Argo-native: an inline value overrides the git valueFile, so it survives continuous
   sync and drift detection (git still says `1`, but the inline value wins), and the
   Deployment dropping to 0 replicas is what cleanly unmounts and detaches the
   Longhorn volume — the official detach method. You don't touch git or pause
   Applications by hand.
3. **Play 3 waits** for every Longhorn volume to reach state `detached` (polling up to
   ~5 min) and **aborts** the shutdown if any stays attached, listing the offenders.
4. **Power back up** — servers first (a few seconds apart so etcd can re-form quorum),
   then workers — and **reverse Play 2** by setting each app's inline `replicaCount`
   back to `1`:

   `kubectl patch application.argoproj.io <name> -n argocd -p '{"spec":{"source":{"helm":{"values":{"replicaCount":1}}}}}' --type merge`

   Argo re-scales the Deployments and Longhorn reattaches each volume from the preserved
   replica data, no rebuild.

The `longhorn-pv` label lives on the Argo Application (from the `applications/*.yaml`
manifests in this repo), so after editing it you must **commit and push** so Argo syncs
the change to the live Application. `kubectl drain` of every node is impossible here (the
last node has nowhere to evict to), and `shutdown -h now` alone does *not* guarantee a
clean detach — so treat a Longhorn **backup/snapshot** as your safety net regardless.

## Notes

- Master nodes are control-plane members; `site.yml` and `upgrade-k3s.yml` both run
  one node at a time (`serial: 1`) so an upgrade never drops the k3s quorum.
- `maintenance.yml` never upgrades k3s or manually scales anything — drain + ArgoCD
  handle the workloads, so there is no git commit and nothing to "scale back up".
