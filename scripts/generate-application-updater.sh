#/bin/bash

APPLICATION="$1"
IMAGE="$2"

echo "
  annotations:
    argocd-image-updater.argoproj.io/git-branch: main
    argocd-image-updater.argoproj.io/git-repository: git@github.com:jaredfiorali/infrastructure.git
    argocd-image-updater.argoproj.io/image-list: myalias=$IMAGE:latest
    argocd-image-updater.argoproj.io/myalias.force-update: "true"
    argocd-image-updater.argoproj.io/myalias.helm.image-name: image.repository
    argocd-image-updater.argoproj.io/myalias.helm.image-tag: image.tag
    argocd-image-updater.argoproj.io/myalias.update-strategy: digest
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/write-back-target: helmvalues:charts/fiorali/$APPLICATION.yaml
" > scripts/tmp/updater.yaml