#!/bin/bash
set -e

# Go Database Migration Validator
# Checks migration files for common issues
# Usage: bash migration-check.sh /path/to/migrations

MIGRATIONS_DIR="${1:-migrations}"

echo "=== Database Migration Validator ===" >&2
echo "Directory: $MIGRATIONS_DIR" >&2

if [ ! -d "$MIGRATIONS_DIR" ]; then
    echo "ERROR: Directory $MIGRATIONS_DIR does not exist" >&2
    cat <<EOF
{
  "error": "Directory not found",
  "path": "$MIGRATIONS_DIR"
}
EOF
    exit 1
fi

ERRORS=0
WARNINGS=0
ISSUES=()

add_issue() {
    local severity="$1"
    local message="$2"
    local file="$3"
    ISSUES+=("{\"severity\":\"$severity\",\"message\":\"$message\",\"file\":\"$file\"}")
    if [ "$severity" = "error" ]; then
        ERRORS=$((ERRORS + 1))
    else
        WARNINGS=$((WARNINGS + 1))
    fi
}

# Check for matching up/down pairs
echo "Checking for matching up/down migration pairs..." >&2
for up_file in "$MIGRATIONS_DIR"/*.up.sql; do
    [ -f "$up_file" ] || continue
    base=$(basename "$up_file" .up.sql)
    down_file="$MIGRATIONS_DIR/${base}.down.sql"
    if [ ! -f "$down_file" ]; then
        add_issue "error" "Missing down migration" "$up_file"
    fi
done

# Check for sequential numbering
echo "Checking sequential numbering..." >&2
PREV_NUM=0
for file in "$MIGRATIONS_DIR"/*.up.sql; do
    [ -f "$file" ] || continue
    NUM=$(basename "$file" | grep -oE '^[0-9]+')
    if [ -n "$NUM" ]; then
        EXPECTED=$((PREV_NUM + 1))
        if [ "$((10#$NUM))" -ne "$EXPECTED" ] && [ "$PREV_NUM" -ne 0 ]; then
            add_issue "warning" "Gap in numbering: expected $EXPECTED, got $NUM" "$file"
        fi
        PREV_NUM=$((10#$NUM))
    fi
done

# Check for transactions in migrations
echo "Checking for transaction usage..." >&2
for file in "$MIGRATIONS_DIR"/*.up.sql; do
    [ -f "$file" ] || continue
    if ! grep -qi "BEGIN\|START TRANSACTION" "$file"; then
        add_issue "warning" "Migration not wrapped in transaction" "$file"
    fi
done

# Check for dangerous operations
echo "Checking for dangerous operations..." >&2
for file in "$MIGRATIONS_DIR"/*.up.sql; do
    [ -f "$file" ] || continue
    if grep -qi "DROP TABLE" "$file" && ! grep -qi "IF EXISTS" "$file"; then
        add_issue "warning" "DROP TABLE without IF EXISTS" "$file"
    fi
    if grep -qi "TRUNCATE" "$file"; then
        add_issue "error" "TRUNCATE in migration — potentially destructive" "$file"
    fi
    if grep -qi "DELETE FROM.*WHERE" "$file"; then
        add_issue "warning" "DELETE with WHERE in migration — verify intent" "$file"
    fi
done

# Count migrations
UP_COUNT=$(find "$MIGRATIONS_DIR" -name "*.up.sql" 2>/dev/null | wc -l | tr -d ' ')
DOWN_COUNT=$(find "$MIGRATIONS_DIR" -name "*.down.sql" 2>/dev/null | wc -l | tr -d ' ')

ISSUES_JSON=$(printf '%s,' "${ISSUES[@]}")
ISSUES_JSON="[${ISSUES_JSON%,}]"

cat <<EOF
{
  "path": "$MIGRATIONS_DIR",
  "summary": {
    "up_migrations": $UP_COUNT,
    "down_migrations": $DOWN_COUNT,
    "errors": $ERRORS,
    "warnings": $WARNINGS
  },
  "issues": ${ISSUES_JSON:-[]}
}
EOF

echo "" >&2
echo "Found $UP_COUNT up, $DOWN_COUNT down migrations" >&2
echo "Results: $ERRORS errors, $WARNINGS warnings" >&2

if [ $ERRORS -gt 0 ]; then
    exit 1
fi
