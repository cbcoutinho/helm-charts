#!/bin/bash
# Render a chart's artifacthub.io/changes annotation into a Markdown
# release-notes.md inside the chart directory, so chart-releaser (`cr`) uses it
# as the GitHub Release body instead of falling back to the chart description.
#
# This is what Renovate surfaces as the "Release Notes" section in consumer PRs
# (e.g. the gitops repos). Without it, every release body is just the static
# chart description and no changelog ever appears downstream.
#
# Usage: scripts/render-release-notes.sh <chart-name>
set -euo pipefail

CHART_NAME="${1:?Usage: $0 <chart-name>}"
CHART_DIR="charts/$CHART_NAME"
CHART_YAML="$CHART_DIR/Chart.yaml"

if [ ! -f "$CHART_YAML" ]; then
    echo "Error: $CHART_YAML not found" >&2
    exit 1
fi

version=$(yq '.version' "$CHART_YAML")

# Render the artifacthub.io/changes annotation (itself a YAML list embedded as a
# block string) into Markdown bullets. Empty/missing annotation -> empty output,
# in which case we skip writing the file so `cr` falls back to the description.
notes=$(
    yq '.annotations["artifacthub.io/changes"] // ""' "$CHART_YAML" \
        | yq -p yaml '.[] | "- **" + .kind + "**: " + .description' 2>/dev/null \
        || true
)

if [ -z "$notes" ]; then
    echo "No artifacthub.io/changes entries for $CHART_NAME, leaving release notes to chart description"
    exit 0
fi

{
    echo "## $CHART_NAME-$version"
    echo
    echo "$notes"
} > "$CHART_DIR/release-notes.md"

echo "Wrote $CHART_DIR/release-notes.md:"
cat "$CHART_DIR/release-notes.md"
