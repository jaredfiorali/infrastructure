---
name: Deploy
description: Deploy homelab changes by bumping the Fiorali chart version and pushing to main; check ArgoCD/GitOps deploy status.
---

# Infrastructure Deploy Skill

**Context window:** 131072 tokens
**Output size:** 32768 tokens

## When to use
When the user wants to deploy changes, trigger a rollout, or check deployment status of the homelab infrastructure.

## Review gate (do not skip — repo-wide)
Never commit or push anything without the user reviewing first. This is not specific to deploys.
1. Make changes, then run `git status` and `git diff` and show them to the user.
2. Wait for explicit approval before `git commit` or `git push`.
3. Hold amendments, history rewrites, and force-pushes until confirmed too.
4. Deploy mechanics (bump version, ArgoCD sync checks) may proceed after review, but the commit/push itself waits for the go-ahead.

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

### Gotcha: every app that renders the changed object must be bumped
Bumping `Chart.yaml` only redeploys apps whose `targetRevision` points at the new version. Many apps pin a specific version in `applications/<app>.yaml`:
```yaml
    targetRevision: '0.3.164'   # pins this app to that chart version
```
If the change you made lives in a ConfigMap/ServiceMonitor/etc. that a *different* app deploys, bumping the chart version does nothing for that app. Find which ArgoCD app owns the object, then bump **its** `targetRevision` to match:
```bash
# Who owns this object?
kubectl get configmap kromgo-configmap -n monitoring -o yaml | grep tracking-id
# Which app pins the version?
grep -rn targetRevision applications/
```
Then bump that app's `applications/<app>.yaml` `targetRevision` to the new chart version and commit it in the same commit. After pushing, force the app-of-apps to pick it up:
```bash
kubectl patch application app-of-apps -n argocd -p '{"operation":{"sync":{"revision":"HEAD"}}}' --type merge
```
Verify the *deployed* object actually changed (not just the chart) before declaring success:
```bash
kubectl get configmap kromgo-configmap -n monitoring -o yaml | grep -A1 "name: <metric>"
```

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