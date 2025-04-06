# Fiorali Infrastructure README

A central place to hold Fiorali infrastructure definitions

## ArgoCD

### ArgoCD Applications

To create a basic application, simply update and deploy this manifest in ArgoCD:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <service-name>
spec:
  destination:
    namespace: downloader
    server: https://kubernetes.default.svc
  source:
    path: ''
    repoURL: https://jaredfiorali.github.io/infrastructure/
    targetRevision: '*'
    chart: fiorali
    helm:
      valueFiles:
        - values.yaml
        - <service-name>.yaml
  sources: []
  project: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Where:

- `<service-name>`: is the name of the service you intend to deploy

### ArgoCD Updater

To add an application's image to the argocd updater, add the following annotations to the ArgoCD Application:

```yaml
  annotations:
    argocd-image-updater.argoproj.io/git-branch: main
    argocd-image-updater.argoproj.io/git-repository: git@github.com:jaredfiorali/infrastructure.git
    argocd-image-updater.argoproj.io/image-list: myalias=homeassistant/home-assistant:latest
    argocd-image-updater.argoproj.io/myalias.force-update: "true"
    argocd-image-updater.argoproj.io/myalias.helm.image-name: image.repository
    argocd-image-updater.argoproj.io/myalias.helm.image-tag: image.tag
    argocd-image-updater.argoproj.io/myalias.update-strategy: digest
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/write-back-target: helmvalues:charts/fiorali/home-assistant.yaml
```

Where:

- `<image-name>`: is the name of the docker image you intend to have updated
- `<application>`: is the name of the application you are working with
