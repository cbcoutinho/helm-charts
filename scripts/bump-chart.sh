#!/bin/bash
# Bump a specific chart's version using Commitizen
# Usage: scripts/bump-chart.sh <chart-name> [--increment PATCH|MINOR|MAJOR]
set -euo pipefail

CHART_NAME="${1:?Usage: $0 <chart-name> [--increment PATCH|MINOR|MAJOR]}"
shift

# Parse optional --increment flag
INCREMENT=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --increment)
            INCREMENT="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Usage: $0 <chart-name> [--increment PATCH|MINOR|MAJOR]" >&2
            exit 1
            ;;
    esac
done

CHART_DIR="charts/$CHART_NAME"

# Validate dependencies
command -v uv >/dev/null 2>&1 || {
    echo "Error: uv not found" >&2
    echo "  Install from https://docs.astral.sh/uv/" >&2
    exit 1
}

# Validate chart directory structure
if [ ! -d "$CHART_DIR" ]; then
    echo "Error: Chart directory not found: $CHART_DIR" >&2
    exit 1
fi

if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
    echo "Error: Chart.yaml not found in $CHART_DIR" >&2
    exit 1
fi

if [ ! -f "$CHART_DIR/.cz.toml" ]; then
    echo "Error: .cz.toml not found in $CHART_DIR" >&2
    exit 1
fi

cd "$CHART_DIR"

echo "Bumping version for chart: $CHART_NAME"
if [ -n "$INCREMENT" ]; then
    echo "  Forcing $INCREMENT bump"
fi

# Build commitizen command
CZ_CMD="uv run cz --config .cz.toml bump --yes"
if [ -n "$INCREMENT" ]; then
    CZ_CMD="$CZ_CMD --increment $INCREMENT"
fi

# Run commitizen bump and capture output
if ! output=$($CZ_CMD 2>&1); then
    cd ../..

    # Check if this is the expected "no commits to bump" case
    if echo "$output" | grep -q "\[NO_COMMITS_TO_BUMP\]"; then
        echo "NO_COMMITS_TO_BUMP"
        exit 0
    fi

    # Otherwise, this is an actual error
    echo "Error: Version bump failed for $CHART_NAME" >&2
    echo "$output" >&2
    exit 1
fi

echo "$output"
echo ""
echo "Chart $CHART_NAME version bumped successfully"

cd ../..
