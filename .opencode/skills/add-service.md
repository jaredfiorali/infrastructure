---
name: Add Service
description: Add a new service to the Fiorali k3s homelab via a per-service Helm override file, then bump the chart version to deploy.
---

# Add a New Service to Fiorali

**Context window:** 131072 tokens
**Output size:** 32768 tokens

**When to use:** User wants to deploy a new application to their Kubernetes homelab cluster.

**Cluster details (Oct 2025):**
- 10 RPi nodes (5x RPi 4 workers, 5x RPi 5 masters), k3s v1.37.1
- Total cluster memory: ~34GB; most Pi 4s 20-40% memory utilization, Pi 5s 50-65%
- New namespace pattern: individual namespaces per service (e.g., `home-assistant`, `scrypted`)
- 26 active namespaces; services hosted in `downloader`, `monitoring`, `loki`, `longhorn-system`, etc.

**Prerequisites:** 
- Access to `/Users/jared/Documents/infrastructure`
- Understanding of the service requirements (containers, ports, storage, env vars)

## Workflow

### 1. Create the Namespace (if new)

For new services, create a dedicated namespace:
```bash
kubectl create namespace <service-name> --kubeconfig=/Users/jared/Documents/infrastructure/kubeconfig
```

### 2. Create the Service Override File

Create a new YAML file in `/Users/jared/Documents/infrastructure/charts/fiorali/` named after the service:

```bash
cd /Users/jared/Documents/infrastructure/charts/fiorali/
touch new-service.yaml
```

### 3. Define Service Values

Write the Helm values override for the service. Most services follow this pattern:

```yaml
replicaCount: 1

image:
  repository: ghcr.io/your-username/new-service
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

resources:
  requests:
    cpu: "50m"
    memory: "100Mi"
  limits:
    cpu: "200m"
    memory: "500Mi"

env:
  - name: TZ
    value: "America/New_York"
```

**Resource guidelines based on cluster:**
- CPU-bound services (plex, transmission): request 200m+, limit 500m
- Memory-bound services (home-assistant, dawarich): request 256Mi+, limit 1Gi
- Small services (grafana, gatus): 50m CPU, 100Mi memory is sufficient

### 4. Handle Secrets (if needed)

If the service needs passwords, API keys, or tokens:
1. Store secrets in AWS Parameter Store (use External Secrets Operator)
2. Reference them in the service YAML using secretRef patterns
3. Reference: `external-secrets.yaml` for setup

### 5. Add Ingress (if service needs web access)

Define ingress rules in the service YAML:

```yaml
ingress:
  enabled: true
  className: cloudflared
  hosts:
    - host: "newservice.yourdomain.com"
      paths:
        - path: /
          pathType: Prefix
```

### 6. Bump Chart Version

Edit `/Users/jared/Documents/infrastructure/charts/fiorali/Chart.yaml` and increment the version:

```yaml
version: 0.2.171  # increment from current
```

### 7. Commit and Push

```bash
cd /Users/jared/Documents/infrastructure
git add charts/fiorali/new-service.yaml charts/fiorali/Chart.yaml
git commit -m "Add new-service to fleet"
git push origin main
```

### 8. Monitor Deployment

- GitHub Actions will trigger `helm package` and publish to GitHub Pages
- ArgoCD will sync the new chart version
- Check ArgoCD dashboard or use `kubectl get application fiorali -n argocd`
- Monitor logs with `kubectl logs <pod-name> -n <namespace>` or Grafana

## Troubleshooting

- **Service not appearing:** Check that the override file is valid YAML and properly named
- **Secrets not loading:** Verify External Secrets Operator is running and params exist in Parameter Store
- **No web access:** Confirm ingress host resolves through Cloudflare/Zero Trust
- **Longhorn volume issues:** Ensure storage class `longhorn` is available and healthy
- **High resource usage:** Check `kubectl top pods --namespace=<namespace>` for CPU/memory

## Reference Services

- For media apps (sonarr/radarr): Look at `sonarr.yaml`, `radarr.yaml`
- For monitoring: Look at `grafana.yaml`, `prometheus.yaml`
- For proxy/ingress: Look at `cloudflared.yaml`
- For databases: Look at `influxdb.yaml`, `postgres.yaml`
- For home automation: Look at `home-assistant.yaml`, `scrypted.yaml`