#/bin/bash

APPLICATION="$1"
NAMESPACE="$2"

echo "
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APPLICATION
spec:
  destination:
    namespace: $NAMESPACE
    server: https://kubernetes.default.svc
  source:
    path: ''
    repoURL: https://jaredfiorali.github.io/infrastructure/
    targetRevision: '*'
    chart: fiorali
    helm:
      valueFiles:
        - values.yaml
        - $APPLICATION.yaml
  sources: []
  project: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
" > scripts/tmp/create.yaml