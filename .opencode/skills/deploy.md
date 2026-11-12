---
name: Deploy
description: Deploy homelab changes by bumping the Fiorali chart version and pushing to main; check ArgoCD/GitOps deploy status.
---

# Infrastructure Deploy Skill

**Context window:** 131072 tokens
**Output size:** 32768 tokens

## When to use
When the user wants to deploy changes, trigger a rollout, or check deployment status of the homelab infrastructure.

## How deployment works in this repo

This is a GitOps setup where deployment is triggered by **bumping the Chart.yaml version**, not by commit hash. ArgoCD watches the chart version on GitHub Pages.

### Standard deploy workflow

```bash
cd ~/Documents/infrastructure

# 1. Check what changed
git status
git diff

# 2. Bump the Chart.yaml version (e.g., 0.2.170 -> 0.2.171)
# Edit charts/fiorali/Chart.yaml - increment the patch version

# 3. Commit and push
git add charts/fiorali/Chart.yaml [other changed files]
git commit -m "chore: bump chart version for deployment"
git push origin main
```

Pushing to `main` triggers the GitHub Actions workflow which:
1. Packages the Helm chart
2. Pushes it to GitHub Releases
3. Deploys to GitHub Pages

ArgoCD then detects the new chart version and syncs.

### Checking deployment status
```bash
# Check ArgoCD sync status
kubectl get application -n argocd
kubectl get application -n argocd | grep fiorali

# Check specific application
kubectl get application fiorali -n argocd -o yaml
kubectl get application <app-name> -n argocd -o yaml

# Check recent pods
kubectl get pods --all-namespaces --sort-by=.metadata.creationTimestamp | head -20

# Monitor pod rollout
kubectl rollout status deployment/<app-name> -n <namespace>
```

### Manual Helm upgrade (for emergencies)
```bash
helm upgrade fiorali ./charts/fiorali/ -n fiorali
```

### Important notes
- **Chart version drives deployment**: Bumping version = new deploy. No version bump = no deploy.
- **Longhorn is manual**: Not auto-synced by ArgoCD due to criticality
- **External secrets**: Require AWS Parameter Store access via Kubernetes credentials
- **After deployment**: Use Popeye (`kubectl run popeye`) to validate cluster health
- **Raspberry Pis have limited resources**: Monitor `kubectl top pods` to check resource usage

### Version bumping convention
- Patch version (0.2.X) for routine deploys
- Minor version (0.X.0) for significant changes
- Major version (X.0.0) for breaking changes

### Troubleshooting deployment issues
If deployment is failing:
1. Check ArgoCD logs for specific error messages
2. Use `kubectl logs` to examine pod logs for specific application errors
3. Verify that the chart version has been incremented in Chart.yaml
4. Verify that your changes are correctly formatted YAML
5. Check for any missing secrets or configuration issues