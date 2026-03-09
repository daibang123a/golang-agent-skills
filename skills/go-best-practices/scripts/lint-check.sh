#!/bin/bash
set -e

# Go Best Practices Lint Check
# Runs a comprehensive set of Go linters and analyzers
# Usage: bash lint-check.sh /path/to/project

PROJECT_DIR="${1:-.}"

echo "=== Go Best Practices Lint Check ===" >&2
echo "Project: $PROJECT_DIR" >&2
echo "" >&2

cleanup() {
    rm -f /tmp/go-lint-results-$$.json
}
trap cleanup EXIT

cd "$PROJECT_DIR"

RESULTS=()
PASS=0
FAIL=0
WARN=0

check() {
    local name="$1"
    local cmd="$2"
    local severity="$3"

    echo "Running: $name..." >&2
    if eval "$cmd" > /dev/null 2>&1; then
        RESULTS+=("{\"check\":\"$name\",\"status\":\"pass\",\"severity\":\"$severity\"}")
        PASS=$((PASS + 1))
    else
        RESULTS+=("{\"check\":\"$name\",\"status\":\"fail\",\"severity\":\"$severity\"}")
        if [ "$severity" = "error" ]; then
            FAIL=$((FAIL + 1))
        else
            WARN=$((WARN + 1))
        fi
    fi
}

# Critical checks
check "go-vet" "go vet ./..." "error"
check "go-build" "go build ./..." "error"
check "race-detector" "go test -race -count=1 -short ./..." "error"

# High-priority checks
if command -v staticcheck &> /dev/null; then
    check "staticcheck" "staticcheck ./..." "error"
else
    echo "SKIP: staticcheck not installed" >&2
fi

if command -v golangci-lint &> /dev/null; then
    check "golangci-lint" "golangci-lint run ./..." "warning"
else
    echo "SKIP: golangci-lint not installed" >&2
fi

# Medium checks
check "go-mod-tidy" "go mod tidy -diff" "warning"

if command -v fieldalignment &> /dev/null; then
    check "fieldalignment" "fieldalignment ./..." "info"
else
    echo "SKIP: fieldalignment not installed (go install golang.org/x/tools/go/analysis/passes/fieldalignment/cmd/fieldalignment@latest)" >&2
fi

# Format check
UNFORMATTED=$(gofmt -l .)
if [ -z "$UNFORMATTED" ]; then
    RESULTS+=("{\"check\":\"gofmt\",\"status\":\"pass\",\"severity\":\"error\"}")
    PASS=$((PASS + 1))
else
    RESULTS+=("{\"check\":\"gofmt\",\"status\":\"fail\",\"severity\":\"error\",\"files\":\"$UNFORMATTED\"}")
    FAIL=$((FAIL + 1))
fi

# Output JSON results
RESULTS_JSON=$(printf '%s,' "${RESULTS[@]}")
RESULTS_JSON="[${RESULTS_JSON%,}]"

cat <<EOF
{
  "project": "$PROJECT_DIR",
  "summary": {
    "pass": $PASS,
    "fail": $FAIL,
    "warn": $WARN,
    "total": $((PASS + FAIL + WARN))
  },
  "checks": $RESULTS_JSON
}
EOF

echo "" >&2
echo "Results: $PASS passed, $FAIL failed, $WARN warnings" >&2

if [ $FAIL -gt 0 ]; then
    exit 1
fi
