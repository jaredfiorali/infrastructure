# Fiorali Infrastructure README

A central place to hold Fiorali infrastructure definitions

## ArgoCD Updater

To add an application's image to the argocd updater, add the following annotations to the ArgoCD Application:

```yaml
  annotations:
    argocd-image-updater.argoproj.io/git-branch: main
    argocd-image-updater.argoproj.io/git-repository: git@github.com:jaredfiorali/infrastructure.git
    argocd-image-updater.argoproj.io/image-list: myalias=<image-name>:latest
    argocd-image-updater.argoproj.io/myalias.force-update: "true"
    argocd-image-updater.argoproj.io/myalias.helm.image-name: image.repository
    argocd-image-updater.argoproj.io/myalias.helm.image-tag: image.tag
    argocd-image-updater.argoproj.io/myalias.update-strategy: digest
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/write-back-target: helmvalues:charts/fiorali/<application>.yaml
```

Where:

- `<image-name>`: is the name of the docker image you intend to have updated
- `<application>`: is the name of the application you are working with
