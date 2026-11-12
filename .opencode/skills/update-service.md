---
name: Update Service
description: Update an existing service's image tag, version, or configuration in the homelab.
tags: [infrastructure, homelab, helm, update]
---

## Overview

Services are updated by editing their override file (`charts/fiorali/<service>.yaml`) and bumping the Chart version. The image tag update triggers ArgoCD to redeploy.

## Manual Update

1. Edit the service's override file:
   ```bash
   cd ~/Documents/infrastructure
   # Edit image tag, version, or configuration
   vim charts/fiorali/<service>.yaml
   ```

2. Bump Chart version:
   ```bash
   # Edit Chart.yaml version field
   vim charts/fiorali/Chart.yaml
   ```

3. Commit and push:
   ```bash
   git add charts/fiorali/<service>.yaml charts/fiorali/Chart.yaml
   git commit -m "Update <service> to <new_version>"
   git push origin main
   ```

4. ArgoCD syncs and the service updates.

## Automated Updates (argocd-image-updater)

The cluster runs argocd-image-updater which scans for image updates. For most services, this handles updates automatically without manual intervention.

**Note:** Longhorn is updated manually and is not auto-synced due to its criticality.

## Rollback

To roll back a service update:
```bash
# Revert the override file and Chart version
git revert <commit_hash>
git push origin main
```