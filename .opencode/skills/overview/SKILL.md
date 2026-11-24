---
name: Infrastructure Overview
description: Context on the fiorali k3s Raspberry Pis homelab — GitOps pattern, single-chart structure, namespaces, and kubectl conventions — before making changes.
---

# Infrastructure Overview

**Context window:** 131072 tokens
**Output size:** 32768 tokens

This is a Kubernetes homelab called "fiorali" running on 10 Raspberry Pis (5 RPi 4 workers, 5 RPi 5 masters). Understanding this pattern is essential before making changes.

## Architecture

- **Container Orchestration**: k3s lightweight Kubernetes cluster
- **GitOps**: ArgoCD watches GitHub Pages for chart updates and syncs automatically
- **Chart Pattern**: Single Helm chart (`charts/fiorali/`) with per-service override YAML files (~38 services total)
- **CI/CD**: GitHub Actions packages the Helm chart on main branch push
- **Secrets**: AWS Parameter Store + External Secrets Operator
- **Storage**: Longhorn persistent volumes, S3 for critical backups
- **Networking**: MetalLB, cloudflared tunnel, Unifi VLANs (3,5,8,9,10,15,20,24)
- **Monitoring**: Prometheus, Grafana, Loki, Alloy, Kromgo, Popeye, Unifi Poller, Gatus
- **Pod Anti-Affinity**: Critical services spread across multiple nodes for resilience

## Node Details (Oct 2025)

- **Pi 4 Nodes (workers)**: 2-1GB RAM each, 800-1100m CPU usage
- **Pi 5 Nodes (masters)**: 8GB RAM each, 300-600m CPU, 50-65% memory utilization
- **Cluster total**: ~34GB RAM, ~7 cores total

## Key Conventions

### Service Override Pattern
Each deployed service has its own YAML file in `charts/fiorali/` (e.g., `plex.yaml`, `sonarr.yaml`). These override default values from `values.yaml`. The chart templates use these overrides to render Kubernetes manifests.

### Deployment Trigger
**Chart version drives deployment**: ArgoCD watches the chart version, not git commits. To deploy:

1. Make your changes to charts/fiorali/ files
2. Update `~/Documents/infrastructure/charts/fiorali/Chart.yaml` - increment the version on line 18 (e.g., `0.2.170` → `0.2.171`)
3. Commit and push to `main`

### Kubernetes Commands and kubectl usage

All kubectl commands can be run in terminal sessions. The kubeconfig is at `~/Documents/infrastructure/kubeconfig`.

```bash
# Check ArgoCD status
kubectl get application -n argocd
kubectl get application fiorali -n argocd

# Check pod status
kubectl get pods --all-namespaces
kubectl get pods -n argocd
kubectl get pods -n fiorali
kubectl get pods -n monitoring
kubectl get pods -n downloader
kubectl get pods -n loki
kubectl get pods -n longhorn-system

# Get pod logs for troubleshooting
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n argocd
kubectl logs <pod-name> -n fiorali

# Check resource usage
kubectl top pods --all-namespaces
kubectl top nodes

# Get specific pod details
kubectl describe pod <pod-name> -n <namespace>
kubectl get pod <pod-name> -n <namespace> -o yaml
```

## Namespaces

Active namespaces include: `argocd`, `cloudflared`, `dawarich`, `downloader`, `emulatorjs`, `external-secrets`, `home-assistant`, `loki`, `longhorn-system`, `metallb-system`, `monitoring`, `popeye`, `scrypted`, `sillytavern`, `tautulli`, `gatus`, `falco`, `gates`, `postgres`, `pinchflat`, `default`, and system namespaces.

## Monitoring & Debugging

Monitor pods and services:

```bash
kubectl get pods --all-namespaces
kubectl get pods -n argocd
kubectl get pods -n fiorali
kubectl get pods -n monitoring

# Get logs from pods
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --tail 50
kubectl logs <pod-name> -n <namespace> --since=5m
```

## Services List

38 services including:
- **Media stack**: Plex, Sonarr, Radarr, Prowlarr, Flaresolverr, Transmission, Gluetun, Tautulli, Kometa, Pinchflat
- **K8s core**: ArgoCD, External Secrets, Longhorn, MetalLB
- **Monitoring**: Prometheus, Grafana, Loki, Alloy, Kromgo, Popeye, Unifi Poller, Gatus
- **Home**: Home Assistant, Scrypted
- **Other**: Cloudflared, Dawarich, InfluxDB, Linkding, EmulatorJS, Tdarr, Speedtest, DNScrypt, SillyTavern

## Secrets Management

Secrets are stored externally in AWS Parameter Store. The External Secrets Operator syncs them into Kubernetes secrets. Do not hardcode sensitive values in override files.

## Critical Services

- Longhorn (storage) - upgraded manually, not auto-synced by ArgoCD
- ArgoCD - controls all deployments 
- MetalLB - provides LoadBalancer IPs
- cloudflared - external DNS/ingress
- home-assistant - runs on Pi 5, 739Mi RAM usage
- loki - runs across all nodes (Alloy), significant memory usage (773Mi for loki-0)

## Resource Usage Patterns

- **CPU-intensive services**: transmission (147m), loki (327m), prometheus-operator
- **Memory-intensive services**: home-assistant (739Mi), dawarich (483Mi), loki (773Mi)
- **Small services**: gatus (10Mi), grafana (30-100Mi), traefik (49Mi)
- **Longhorn pods**: Heavy on Pi 4 nodes (multiple CSI plugins, instance managers)
- **ArgoCD**: Reasonably light, mostly uses the controller and repo-server

## Important Kubernetes Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get namespaces

# Get specific pod details
kubectl describe pod <pod-name> -n <namespace>
kubectl get pod <pod-name> -n <namespace> -o yaml

# Get logs from pods
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --tail 50
kubectl logs <pod-name> -n <namespace> --since=5m

# Check Longhorn status
kubectl get pods -n longhorn-system

# Check ArgoCD status
kubectl get application -n argocd
kubectl get application <app-name> -n argocd -o yaml
```

## Reference Docs

The repo's README.md contains extensive documentation (556 lines) covering the full architecture, networking, backup strategy, and operational procedures. Consult it for details not covered here.