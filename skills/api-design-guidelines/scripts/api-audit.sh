#!/bin/bash
set -e

# Go API Design Audit Script
# Scans a Go project for common API design issues
# Usage: bash api-audit.sh /path/to/project

PROJECT_DIR="${1:-.}"

echo "=== Go API Design Audit ===" >&2
echo "Project: $PROJECT_DIR" >&2

cleanup() {
    rm -f /tmp/api-audit-$$.tmp
}
trap cleanup EXIT

cd "$PROJECT_DIR"

ISSUES=()
WARNINGS=0
ERRORS=0

add_issue() {
    local severity="$1"
    local rule="$2"
    local message="$3"
    local file="$4"
    ISSUES+=("{\"severity\":\"$severity\",\"rule\":\"$rule\",\"message\":\"$message\",\"file\":\"$file\"}")
    if [ "$severity" = "error" ]; then
        ERRORS=$((ERRORS + 1))
    else
        WARNINGS=$((WARNINGS + 1))
    fi
}

# Check for default http.ListenAndServe (no timeouts)
echo "Checking for default http.ListenAndServe..." >&2
FILES=$(grep -rn "http.ListenAndServe" --include="*.go" . 2>/dev/null || true)
if [ -n "$FILES" ]; then
    while IFS= read -r line; do
        FILE=$(echo "$line" | cut -d: -f1)
        add_issue "error" "R6" "Using http.ListenAndServe without timeouts" "$FILE"
    done <<< "$FILES"
fi

# Check for missing MaxBytesReader
echo "Checking for request body size limits..." >&2
HANDLERS=$(grep -rn "json.NewDecoder(r.Body)" --include="*.go" . 2>/dev/null || true)
MAX_BYTES=$(grep -rn "MaxBytesReader" --include="*.go" . 2>/dev/null || true)
if [ -n "$HANDLERS" ] && [ -z "$MAX_BYTES" ]; then
    add_issue "error" "Q2" "No http.MaxBytesReader found — request bodies are unlimited" ""
fi

# Check for io.ReadAll on request bodies
echo "Checking for io.ReadAll on request bodies..." >&2
READALL=$(grep -rn "io.ReadAll(r.Body)" --include="*.go" . 2>/dev/null || true)
if [ -n "$READALL" ]; then
    while IFS= read -r line; do
        FILE=$(echo "$line" | cut -d: -f1)
        add_issue "warning" "Q3" "Using io.ReadAll instead of json.Decoder" "$FILE"
    done <<< "$READALL"
fi

# Check for health endpoints
echo "Checking for health endpoints..." >&2
HEALTH=$(grep -rn "healthz\|health\|readyz\|ready" --include="*.go" . 2>/dev/null || true)
if [ -z "$HEALTH" ]; then
    add_issue "warning" "O5" "No health check endpoints found (/healthz, /readyz)" ""
fi

# Check for structured logging
echo "Checking for structured logging..." >&2
FMT_PRINT=$(grep -rn "fmt.Printf\|fmt.Println\|log.Print" --include="*.go" . 2>/dev/null | grep -v "_test.go" || true)
SLOG=$(grep -rn "slog\." --include="*.go" . 2>/dev/null || true)
if [ -n "$FMT_PRINT" ] && [ -z "$SLOG" ]; then
    add_issue "warning" "O1" "Using fmt/log for logging instead of slog (structured logging)" ""
fi

# Check for signal handling (graceful shutdown)
echo "Checking for graceful shutdown..." >&2
SIGNAL=$(grep -rn "signal.Notify\|signal.NotifyContext" --include="*.go" . 2>/dev/null || true)
if [ -z "$SIGNAL" ]; then
    add_issue "warning" "G1" "No signal handling found — service may not shutdown gracefully" ""
fi

# Check for hardcoded secrets
echo "Checking for hardcoded secrets..." >&2
SECRETS=$(grep -rn "password.*=.*\"" --include="*.go" . 2>/dev/null | grep -v "_test.go" | grep -v "Password string" || true)
if [ -n "$SECRETS" ]; then
    while IFS= read -r line; do
        FILE=$(echo "$line" | cut -d: -f1)
        add_issue "error" "A5" "Possible hardcoded secret detected" "$FILE"
    done <<< "$SECRETS"
fi

# Output results as JSON
ISSUES_JSON=$(printf '%s,' "${ISSUES[@]}")
ISSUES_JSON="[${ISSUES_JSON%,}]"

cat <<EOF
{
  "project": "$PROJECT_DIR",
  "summary": {
    "errors": $ERRORS,
    "warnings": $WARNINGS,
    "total": $((ERRORS + WARNINGS))
  },
  "issues": ${ISSUES_JSON:-[]}
}
EOF

echo "" >&2
echo "Results: $ERRORS errors, $WARNINGS warnings" >&2
