# CLAUDE.md

Claude Code specific guidance for this repository.

## Quick Reference

- This is a **Go agent skills** repository
- Skills are in `skills/` directory
- Each skill has a `SKILL.md` (required) and optional `scripts/`, `references/`, `assets/`
- All bash scripts must use `set -e` and write status to stderr
- Go code examples target Go 1.22+

## Common Tasks

### Validate a skill

```bash
# Check SKILL.md has valid frontmatter
head -20 skills/{name}/SKILL.md

# Verify scripts are executable
find skills/{name}/scripts -name "*.sh" -exec test -x {} \; -print

# Run shellcheck on scripts
find skills/ -name "*.sh" -exec shellcheck {} \;
```

### Add a new skill

1. `mkdir -p skills/{name}/{scripts,references}`
2. Create `skills/{name}/SKILL.md` with YAML frontmatter
3. Add scripts and references as needed
4. Update root `README.md` with the new skill entry

### Test Go code examples

```bash
# Verify code examples compile
go vet ./...
staticcheck ./...
```

## Style

- SKILL.md: Markdown with YAML frontmatter
- Scripts: Bash with `#!/bin/bash` and `set -e`
- Go examples: Follow `gofmt` formatting
- Use tables for rule listings (Priority | Rule | Description)
