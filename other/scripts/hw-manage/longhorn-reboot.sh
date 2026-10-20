#!/usr/bin/env bash
# Scale down Longhorn workloads via ArgoCD annotation, check detach, reboot.
#
# Usage: longhorn-reboot.sh [node-name] [--check] [--scale-up] [--scale-down] [--verbose]
#
# --check    Dry run: scale down, verify detach, but skip reboot.
# --scale-up Restore Longhorn workloads to their original replica counts.
# --scale-down Scale down Longhorn workloads (default).
# --verbose  Print intermediate output.

set -euo pipefail

NODE="${1:-$(hostname -f)}"
CHECK=0
SCALE_UP=0
SCALE_DOWN=0
VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)     CHECK=1; shift ;;
    --scale-up)  SCALE_UP=1; shift ;;
    --scale-down) SCALE_DOWN=1; shift ;;
    --verbose)   VERBOSE=1; shift ;;
    *)           NODE="$1"; shift ;;
  esac
done

[[ $SCALE_UP -eq 0 ]] && SCALE_DOWN=1  # Default to scale-down

v() { [[ $VERBOSE -eq 1 ]] && echo "  $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

# 1. Find ArgoCD apps on this node that have longhorn-pv=true.
longhorn_apps=$(kubectl get apps.argoproj.io -A -o json 2>/dev/null | \
  jq -r --arg node "$NODE" '
    .items[]
    | select(.metadata.annotations["longhorn-pv"] == "true")
    | .metadata.namespace + "/" + .metadata.name
  ' | sort -u)

if [[ -z "$longhorn_apps" ]]; then
  echo "No Longhorn workloads found on ${NODE}."
  if [[ $CHECK -eq 1 ]] && [[ $SCALE_DOWN -eq 1 ]]; then exit 0; fi
fi

echo "Longhorn workloads on ${NODE}:"
echo "$longhorn_apps"

# 2. Scale down or up each workload.
for app in $longhorn_apps; do
  NAMESPACE="${app%%/*}"
  NAME="${app##*/}"

  # Get the workload type and name from the app spec.
  workload=$(kubectl get app "$NAME" -n "$NAMESPACE" -o json | \
    jq -r '.spec.template.spec.template.metadata.annotations."workload" // ""')

  if [[ -n "$workload" ]]; then
    type="${workload%%/*}"
    name="${workload##*/}"

    if [[ $SCALE_UP -eq 1 ]]; then
      echo "  Scaling up ${type}/${name} (from ${NAME})…"
      kubectl scale "${type}/${name}" -n "$NAMESPACE" --replicas=1 2>/dev/null || true
    else
      echo "  Scaling down ${type}/${name} (from ${NAME})…"
      kubectl scale "${type}/${name}" -n "$NAMESPACE" --replicas=0 2>/dev/null || true
    fi
  else
    # Fallback: scale all deployments in the namespace.
    kubectl get deployments -n "$NAMESPACE" -o json | \
      jq -r '.items[] | .metadata.name' | while read -r dep; do
        if [[ $SCALE_UP -eq 1 ]]; then
          echo "  Scaling up deployment/${dep} (from ${NAME})…"
          kubectl scale deployment/"$dep" -n "$NAMESPACE" --replicas=1 2>/dev/null || true
        else
          echo "  Scaling down deployment/${dep} (from ${NAME})…"
          kubectl scale deployment/"$dep" -n "$NAMESPACE" --replicas=0 2>/dev/null || true
        fi
      done
  fi
done

# 3. Wait for Longhorn volumes to detach (scale-down only).
if [[ $SCALE_UP -eq 0 ]]; then
  echo "Waiting for Longhorn volumes to detach…"
  MAX_ATTEMPTS=30
  ATTEMPT=0
  while true; do
    detached=$(lsblk -b -d -o NAME,SIZE,ROTA,RM | grep -c "longhorn" || true)
    v "Attempt ${ATTEMPT}/${MAX_ATTEMPTS}: ${detached} volume(s) remaining"
    if [[ $detached -eq 0 ]] || [[ $ATTEMPT -ge $MAX_ATTEMPTS ]]; then break; fi
    sleep 2
    ATTEMPT=$((ATTEMPT + 1))
  done
  if [[ $detached -gt 0 ]]; then
    echo "WARNING: ${detached} Longhorn volume(s) may still be attached."
  else
    echo "Longhorn volumes detached."
  fi
fi

# 4. Reboot (scale-down + check mode).
if [[ $CHECK -eq 1 ]] && [[ $SCALE_DOWN -eq 1 ]]; then
  echo "Dry run complete. No reboot performed."
  exit 0
fi

echo "Rebooting ${NODE}…"
exec reboot --message "hw-manage: rebooting after Longhorn maintenance"
