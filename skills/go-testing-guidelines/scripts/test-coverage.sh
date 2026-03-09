#!/bin/bash
set -e

# Go Test Coverage Analysis
# Runs tests with coverage and produces a report
# Usage: bash test-coverage.sh /path/to/project [min-coverage]

PROJECT_DIR="${1:-.}"
MIN_COVERAGE="${2:-80}"

echo "=== Go Test Coverage Analysis ===" >&2
echo "Project: $PROJECT_DIR" >&2
echo "Min coverage: ${MIN_COVERAGE}%" >&2

cleanup() {
    rm -f /tmp/coverage-$$.out /tmp/coverage-$$.html
}
trap cleanup EXIT

cd "$PROJECT_DIR"

# Run tests with coverage
echo "Running tests with coverage..." >&2
go test -race -coverprofile=/tmp/coverage-$$.out -covermode=atomic ./... 2>&1 | \
    grep -E "^(ok|FAIL|---)" >&2 || true

# Parse coverage
TOTAL_COVERAGE=$(go tool cover -func=/tmp/coverage-$$.out | grep "^total:" | awk '{print $3}' | tr -d '%')

# Get per-package coverage
PACKAGES=$(go tool cover -func=/tmp/coverage-$$.out | grep "^total:" -B 9999 | \
    awk -F'\t' '/^[^t]/ {gsub(/ +/, "", $NF); print $1 "|" $NF}' | \
    sort -t'|' -k2 -n | head -20)

# Count uncovered functions
UNCOVERED=$(go tool cover -func=/tmp/coverage-$$.out | awk '{print $3}' | grep "0.0%" | wc -l | tr -d ' ')
TOTAL_FUNCS=$(go tool cover -func=/tmp/coverage-$$.out | wc -l | tr -d ' ')

# Generate HTML report
go tool cover -html=/tmp/coverage-$$.out -o /tmp/coverage-$$.html 2>/dev/null || true

# Check if coverage meets minimum
PASS="true"
if (( $(echo "$TOTAL_COVERAGE < $MIN_COVERAGE" | bc -l 2>/dev/null || echo 0) )); then
    PASS="false"
fi

# Output JSON
cat <<EOF
{
  "project": "$PROJECT_DIR",
  "total_coverage": $TOTAL_COVERAGE,
  "min_coverage": $MIN_COVERAGE,
  "pass": $PASS,
  "total_functions": $TOTAL_FUNCS,
  "uncovered_functions": $UNCOVERED,
  "html_report": "/tmp/coverage-$$.html"
}
EOF

echo "" >&2
echo "Total coverage: ${TOTAL_COVERAGE}% (minimum: ${MIN_COVERAGE}%)" >&2
echo "Uncovered functions: $UNCOVERED / $TOTAL_FUNCS" >&2

if [ "$PASS" = "false" ]; then
    echo "FAIL: Coverage below minimum threshold" >&2
    exit 1
fi
