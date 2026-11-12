---
name: Metrics Pipeline
description: Add or update a homelab service's monitoring badges (Uptime + Latency) in the README by going through the Gatus -> Kromgo -> git-sync -> README pipeline
---

# Metrics Pipeline

Add or change a service's live badges (Uptime 30d + Latency 30d) shown in the README. The pipeline is:

**Gatus** (health check) → **Kromgo** (turn Gatus results into metrics) → **git-sync** (fetch metrics and publish JSON + SVG to the `gh-pages` branch) → **README** (render the badges).

The **Gatus key** is the single anchor. Derive it first, then use it verbatim in every downstream stage.

## The Gatus key

`<group-with-hyphens>_<name>` — the endpoint's `group` (spaces → hyphens) + `_` + the endpoint `name`.

Example: `name: romm`, `group: media management` → key `media-management_romm`.

## Stages

### 1. Gatus — `charts/fiorali/gatus-configmap.yaml`
Add an entry under `endpoints:` (next to siblings in the same group):
```yaml
- name: <name>
  url: http://<service>.fiora.li/<health-path>
  group: <group>
  conditions: ["[STATUS] == 200", "[RESPONSE_TIME] < 1000"]
```
- Match the service's real health semantics. Some are not `200`: transmission returns `409` on its RPC endpoint, sillytavern `401`. Keep `== 200` plus the `< 1000` response-time gate only for slow services.
- The `url`, `group`, and `name` together fix the Gatus key for the rest of the pipeline.

### 2. Kromgo — `charts/fiorali/kromgo-configmap.yaml`
Add two metrics keyed on the Gatus key:
```yaml
- name: <service>_uptime
  query: round(sum(increase(gatus_results_total{key="<key>", success="true"}[30d])) / sum(increase(gatus_results_total{key="<key>"}[30d])) * 100, 1)
  suffix: "%"
  colors: [{color: "green", min: 99, max: 100}, {color: "orange", min: 95, max: 98.99}, {color: "red", min: 0, max: 94.99}]
- name: <gatus_key>
  query: round(avg_over_time(gatus_results_duration_seconds{key="<key>"}[30d]) * 1000, 1)
  suffix: "ms"
  colors: [{color: "green", min: 0, max: 150}, {color: "orange", min: 151, max: 400}, {color: "red", min: 401, max: 999999}]
```
- The response-time metric **name must equal the Gatus key** — the README badge and the SVG filename are derived from it.
- Copy a sibling service's color thresholds and adjust the ranges.

### 3. git-sync — `charts/fiorali/git-sync.yaml`
Add both metric names to the `KROMGO_QUERIES` env value (comma-separated list), next to siblings:
- `<service>_uptime` → produces `<service>_uptime.json` (the Up badge). The script skips `*_uptime` when downloading charts.
- `<gatus_key>` → produces `<gatus_key>.json` (Latency badge) **and** `badges/<gatus_key>-chart.svg` (the 30d chart the badge links to).

### 4. README.md — service table row
Add a row to the table for the service's category: Media Management, Kubernetes Core, Monitoring, Home Security, Other, or External. The README section is independent of the Gatus group — place by functional category (e.g. RomM went in **Other** next to emulatorjs, even though its Gatus group is "media management").

Two badges:
```
![Up](https://img.shields.io/endpoint?url=https://jaredfiorali.github.io/infrastructure/<service>_uptime.json&style=flat-square&label=Up&nbsp;30d)&nbsp;[![Latency&nbsp;30d](https://img.shields.io/endpoint?url=https://jaredfiorali.github.io/infrastructure/<gatus_key>.json&style=flat-square&label=Latency&nbsp;30d)](https://jaredfiorali.github.io/infrastructure/badges/<gatus_key>-chart.svg)
```
- The **Metrics column is width-padded** to align the table. Don't hand-space it — measure a neighbor row and rebuild the row programmatically:
```sh
# Column widths of a reference row in the same table (line number varies):
awk 'NR==102{n=split($0,a,"|"); for(i=1;i<=n;i++) print i, length(a[i])}' README.md
```
```python
lines = open("README.md", encoding="utf-8").read().splitlines()
ref = next(l for l in lines if "[radarr](" in l)   # any neighbor in the same table
c = ref.split("|")
badge = "<the badge string from above>"
print("|" + " [romm](https://github.com/rommapp/romm)".ljust(len(c[1])) + "|" +
      c[2].ljust(len(c[3])) + "|" + badge.ljust(len(c[4])) + "|" +
      " Game ROM manager".ljust(len(c[5])) + "|")
```
Reusing the neighbor's criticality column (`c[2]`) verbatim preserves the `●○` glyphs.
- If the service has a web portal, also add it (alphabetically) to the Handy Links list: `- [name](http://<service>.fiora.li)`.
- The badge host `https://jaredfiorali.github.io/infrastructure/` is the GitHub Pages site for the `gh-pages` branch. Change it only if the repo/host moves.

## Finalize (deploy)
Badges stay "unknown" until the change is deployed:
1. Commit the changed files (`gatus-configmap.yaml`, `kromgo-configmap.yaml`, `git-sync.yaml`, `README.md`).
2. Bump `charts/fiorali/Chart.yaml` — ArgoCD only syncs on a chart version change.
3. Push → GitHub Actions compiles/packages the chart → GitHub Pages → ArgoCD syncs.

**Ordering caveat:** Gatus must come up first so the Gatus key exists. Until it does, Kromgo's query and git-sync's fetch return empty for that service.

**Timing:** git-sync runs on a cron (`5 23 * * *`, ~23:05 UTC daily), so badges populate at the next run after deploy.
