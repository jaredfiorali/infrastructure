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

## Gotchas (learned the hard way)

### Verify the metric exists before writing the query
The metric name you *expect* may not exist in the service's current mode. metallb runs FRR-K8s mode, where the obvious `metallb_bgp_session_up` is absent; the real metric is `frrk8s_bgp_session_up`, served by the frr-k8s `frr-metrics` container on port **9141** (HTTPS + SA token). Always confirm the real name and scrape target with Prometheus before wiring the Kromgo query:
```bash
# Does the metric exist and is it being scraped?
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
curl -s -H "Authorization: Bearer $(kubectl get secret prometheus-...-token -n monitoring -o jsonpath='{.data.token}' | base64 -d)" \
  "http://localhost:9090/api/v1/query?query=count(frrk8s_bgp_session_up)"
```

### A ServiceMonitor can scrape but be invisible to Prometheus
An SM may already hit the right endpoint yet never be scraped because it lacks Prometheus's selector label. Prometheus selects SMs by `serviceMonitorSelector: {release: prometheus}` (namespace selector `{}` = all namespaces). If a metric is missing, check the SM's labels first — the fix is often just adding the label, not a new template:
```yaml
# via the chart's helm params in the app that renders the workload:
frr-k8s.prometheus.serviceMonitor.additionalLabels.release=prometheus
```
For metallb this param belongs in `applications/metallb.yaml` (the standalone `chart: metallb` ArgoCD source). fiorali is **not** a Helm umbrella — it only renders metallb CRDs (pools/peers/bfd/ads) — so the controller/speaker/frr-k8s workloads and their SMs come from that separate app, not fiorali's metallb.yaml.

### Confirm the deployed object, not just the chart, changed
A chart version change does not reach a running app until that app's `targetRevision` is bumped and it re-syncs (see `deploy.md` → "every app that renders the changed object must be bumped"). Verify the live ConfigMap/query after deploy:
```bash
kubectl get configmap kromgo-configmap -n monitoring -o yaml | grep -A1 "name: <metric>"
```
And confirm Kromgo actually returns a value, not just that Prometheus does:
```bash
kubectl port-forward -n monitoring svc/kromgo 8080:8080 &
curl -s http://localhost:8080/metallb_uptime   # Kromgo serves by metric name
```
