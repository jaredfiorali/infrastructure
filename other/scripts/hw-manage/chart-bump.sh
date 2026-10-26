#!/usr/bin/env bash
# Bump Chart.yaml version and commit only services that changed since the last bump.
#
# Usage: chart-bump.sh [--minor] [--patch] [--message "custom message"]
#
# Defaults to patch bump (0.2.183 -> 0.2.184).
# Detects the project root (infrastructure/) automatically.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

BUMP="patch"
MSG=""
PROJECT_ROOT=""

# Parse flags and optional project-root argument
while [[ $# -gt 0 ]]; do
  case "$1" in
    --minor)     BUMP="minor"; shift ;;
    --patch)     BUMP="patch"; shift ;;
    --message)   MSG="$2"; shift 2 ;;
    --*)         shift ;;   # unknown flags
    *)           PROJECT_ROOT="$1"; shift ;;  # first non-flag = project root
  esac
done

# Find the project root (where Chart.yaml lives)
ROOT="${PROJECT_ROOT:-$SCRIPT_DIR}"
# Try a few levels up until we find Chart.yaml
for i in 0 1 2 3 4; do
  if [[ -f "$ROOT/Chart.yaml" || -f "$ROOT/charts/fiorali/Chart.yaml" ]]; then
    break
  fi
  ROOT="$(cd "$ROOT/.." 2>/dev/null && pwd)"
done
# Locate Chart.yaml
chart_file="$ROOT/charts/fiorali/Chart.yaml"
if [[ ! -f "$chart_file" ]]; then
  chart_file="$ROOT/Chart.yaml"
fi
if [[ ! -f "$chart_file" ]]; then
  echo "ERROR: Chart.yaml not found at $chart_file"
  exit 1
fi

CD="$ROOT"
cd "$CD"

# Check we're in a git repo
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "ERROR: Not a git repo — run from the infrastructure directory."
  exit 1
fi

chart_file="${chart_file:-$CD/Chart.yaml}"
[[ -f "$chart_file" ]] || { echo "No Chart.yaml found at $chart_file"; exit 1; }

# Pre-pull: save the commit we're bumping FROM
pre_pull=$(git rev-parse HEAD)
echo "Current version: $(grep '^version:' "$chart_file" | awk '{print $2}')"
echo "Pulling from remote..."
git pull

# Find changed chart files between pre-pull and current HEAD
changed=$(git diff --name-only "$pre_pull"..HEAD \
  | grep -E 'charts/fiorali/[^/]+\.yaml' \
  | grep -v 'Chart\.yaml' \
  | sort || true)

# Bump version in Chart.yaml
old_ver=$(grep '^version:' "$chart_file" | awk '{print $2}')
IFS='.' read -r major minor patch <<< "$old_ver"

case "$BUMP" in
  minor) patch=$((patch + 1))
         minor=$((minor + 1)); patch=0 ;;
  patch) patch=$((patch + 1)) ;;
esac

new_ver="${major}.${minor}.${patch}"
sed -i '' "s/^version: $old_ver/version: $new_ver/" "$chart_file"

# Bump targetRevision only for Fiorali chart sources
apps_dir="$CD/applications"
if [[ -d "$apps_dir" ]]; then
  echo "Bumping targetRevision → $new_ver in Fiorali app manifests..."
  find "$apps_dir" -name '*.yaml' | while IFS= read -r file; do
    if grep -q "ghcr.io/jaredfiorali/helm-charts" "$file"; then
      sed -i '' "/ghcr.io\/jaredfiorali\/helm-charts/{n;s/targetRevision: '[^']*'/targetRevision: '$new_ver'/;}" "$file"
    fi
  done
  find "$apps_dir" -name '*.yaml' -exec git add {} \;
  apps_staged="yes"
fi

# Build commit message body
if [[ -n "$changed" ]]; then
  body=$(echo "$changed" | sed 's|.*/||' | awk '{printf "- %s\n", $0}')
else
  body="  (no services changed)"
fi

if [[ -z "$MSG" ]]; then
  MSG="chore: bump Chart.yaml to $new_ver"
else
  MSG="${MSG%.*} ($new_ver)"
fi

msg_body=$(cat <<EOF
${MSG}

Services:
${body}
EOF
)

# Stage and commit
if [[ "$apps_staged" == "yes" ]]; then
  git add "$chart_file" $(echo "$changed" | tr '\n' ' ')
else
  git add "$chart_file"
fi
git commit -m "$msg_body"

echo ""
echo "Bumped $old_ver → $new_ver"
echo "Commited:"
git log --oneline -1
