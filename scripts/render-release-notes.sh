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

version=$(yq -r '.version' "$CHART_YAML")

# The artifacthub.io/changes annotation is itself a YAML list embedded as a
# block string. Missing/empty -> nothing to render, so leave the release body to
# the chart description (cr's built-in fallback).
raw_changes=$(yq '.annotations["artifacthub.io/changes"] // ""' "$CHART_YAML")
if [ -z "$raw_changes" ]; then
    echo "No artifacthub.io/changes entries for $CHART_NAME, leaving release notes to chart description"
    exit 0
fi

# Render only well-formed entries (both kind and description present) into
# Markdown bullets, so malformed items don't produce junk like "- ****:". If a
# NON-empty annotation yields no usable entries (invalid YAML or every item
# missing fields), warn rather than silently shipping the description.
total=$(printf '%s\n' "$raw_changes" | yq -p yaml 'length' 2>/dev/null || echo 0)
# -r/--raw-output: emit raw strings. Without it, yq serialises a string that
# starts with "- " as a YAML-quoted scalar on some versions, producing literal
# quotes in the Markdown (and breaking the '^- ' counter below).
notes=$(printf '%s\n' "$raw_changes" \
    | yq -p yaml -r '.[] | select(has("kind") and has("description")) | "- **" + .kind + "**: " + .description' 2>/dev/null || true)
if [ -z "$notes" ]; then
    echo "Warning: $CHART_NAME has a non-empty artifacthub.io/changes annotation that produced no usable entries (invalid YAML or items missing kind/description); leaving release notes to chart description" >&2
    exit 0
fi

# Warn (but proceed) if some entries were dropped as malformed.
rendered=$(printf '%s\n' "$notes" | grep -c '^- ' || true)
if [ "$total" -gt 0 ] && [ "$rendered" -lt "$total" ]; then
    echo "Warning: $CHART_NAME release notes dropped $((total - rendered)) of $total artifacthub.io/changes entries (missing kind/description)" >&2
fi

# cr reads release-notes.md from the *packaged* chart, so it must not be stripped
# by .helmignore. We can't fully evaluate glob semantics here, but warn loudly on
# the obvious patterns so a new chart doesn't silently regress to the description.
if [ -f "$CHART_DIR/.helmignore" ] \
    && grep -qE '^[[:space:]]*(\*|\*\.md|release-notes(\.md|\*)?)[[:space:]]*$' "$CHART_DIR/.helmignore"; then
    echo "Warning: $CHART_DIR/.helmignore may exclude release-notes.md from the package; cr would fall back to the chart description" >&2
fi

{
    echo "## $CHART_NAME-$version"
    echo
    echo "$notes"
} > "$CHART_DIR/release-notes.md"

echo "Wrote $CHART_DIR/release-notes.md:"
cat "$CHART_DIR/release-notes.md"
