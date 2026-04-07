#!/bin/bash
# Update the artifacthub.io/changes annotation in Chart.yaml from git history
# Usage: scripts/update-artifacthub-changes.sh <chart-name>
set -euo pipefail

CHART_NAME="${1:?Usage: $0 <chart-name>}"
CHART_DIR="charts/$CHART_NAME"

if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
    echo "Error: $CHART_DIR/Chart.yaml not found" >&2
    exit 1
fi

# Find last tag for this chart
last_tag=$(git tag --sort=-creatordate | grep -E "^${CHART_NAME}-[0-9]" | head -n 1 || echo "")

if [ -z "$last_tag" ]; then
    log_range="HEAD"
else
    log_range="${last_tag}..HEAD"
fi

# Map conventional commit types to ArtifactHub change kinds
# Valid kinds: added, changed, deprecated, removed, fixed, security
map_kind() {
    case "$1" in
        feat)     echo "added" ;;
        fix)      echo "fixed" ;;
        security) echo "security" ;;
        *)        echo "changed" ;;
    esac
}

changes_file=$(mktemp)
trap 'rm -f "$changes_file"' EXIT

# Parse conventional commits, skip merge/bump commits and CI-only types
git log --format="%s" $log_range | while IFS= read -r msg; do
    # Skip merge commits and bump commits
    [[ "$msg" =~ ^(Merge|bump:) ]] && continue

    # Match conventional commit format: type(scope)!: description
    if [[ "$msg" =~ ^(feat|fix|docs|refactor|perf|build|chore|security)\(.*\)\!?:\ (.+) ]]; then
        kind=$(map_kind "${BASH_REMATCH[1]}")
        desc="${BASH_REMATCH[2]}"
        # Escape double quotes in description
        desc="${desc//\"/\\\"}"
        echo "- kind: $kind"              >> "$changes_file"
        echo "  description: \"$desc\""   >> "$changes_file"
    fi
done

if [ ! -s "$changes_file" ]; then
    echo "No conventional commits found for annotation, skipping update"
    exit 0
fi

echo "Updating artifacthub.io/changes annotation for $CHART_NAME:"
cat "$changes_file"

yq -i ".annotations[\"artifacthub.io/changes\"] = load_str(\"$changes_file\")" "$CHART_DIR/Chart.yaml"
