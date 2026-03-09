# Contributing to Go Agent Skills

Thank you for your interest in contributing! This guide will help you get started.

## How to Contribute

### Adding a New Skill

1. **Fork the repository** and create a new branch
2. **Create a skill directory** under `skills/` with a kebab-case name
3. **Write the `SKILL.md`** with proper YAML frontmatter
4. **Add supporting files** (scripts, references, assets) as needed
5. **Update the root `README.md`** with your skill's entry
6. **Submit a pull request**

### Skill Requirements

Every skill must have:

- A `SKILL.md` file with valid YAML frontmatter containing:
  - `name` — kebab-case identifier matching the directory name
  - `description` — trigger-rich description (when to use, trigger phrases)
- Clear, prioritized rules organized by category
- Code examples that are correct, compilable Go (target Go 1.22+)

### Quality Checklist

Before submitting:

- [ ] `SKILL.md` has valid YAML frontmatter with `name` and `description`
- [ ] Description includes trigger phrases that help agents activate the skill
- [ ] Rules are categorized and prioritized by impact (Critical → High → Medium → Low)
- [ ] Code examples compile with `go vet`
- [ ] `SKILL.md` is under 500 lines (use `references/` for detailed content)
- [ ] Scripts use `#!/bin/bash`, `set -e`, and write status to stderr
- [ ] Scripts output JSON to stdout for machine readability
- [ ] All markdown files pass a linter

### Writing Good Descriptions

The description is the most important part — it's what agents use to decide whether to load your skill.

**Good:**
```yaml
description: >
  Go database access patterns covering connection pooling, transactions,
  migrations, and testing. Use when setting up database connections,
  writing SQL queries, or implementing repository patterns.
  Triggers: "database setup", "SQL in Go", "connection pool", "migration".
```

**Bad:**
```yaml
description: Database stuff for Go.
```

### Writing Rules

- Use tables for structured rules: `| # | Rule | Description |`
- Prioritize: Critical rules first, Low-impact rules last
- Include code examples for non-obvious rules
- Keep explanations concise — one sentence per rule in the table

### Script Guidelines

Scripts should:
- Use `#!/bin/bash` shebang and `set -e` for fail-fast
- Write human-readable progress to stderr: `echo "Checking..." >&2`
- Output machine-readable JSON to stdout
- Include a `cleanup` trap for temp files
- Accept the project path as the first argument
- Work on macOS and Linux

### Reference Files

- Put detailed documentation in `references/` directory
- Link from `SKILL.md` to references: "For details, see `references/topic.md`"
- Keep references focused on one topic each
- Include runnable code examples

## Development

### Validating Skills

```bash
# Check all SKILL.md files have valid frontmatter
for f in skills/*/SKILL.md; do
    head -1 "$f" | grep -q "^---$" || echo "Missing frontmatter: $f"
done

# Run shellcheck on all scripts
find skills/ -name "*.sh" -exec shellcheck {} \;

# Count lines in SKILL.md files (should be under 500)
for f in skills/*/SKILL.md; do
    lines=$(wc -l < "$f")
    if [ "$lines" -gt 500 ]; then
        echo "WARNING: $f has $lines lines (max 500)"
    fi
done
```

### Testing Scripts

```bash
# Test individual script
cd /tmp && mkdir test-project && cd test-project
go mod init test && echo 'package main; func main() {}' > main.go
bash /path/to/skills/go-best-practices/scripts/lint-check.sh .
```

## Code of Conduct

- Be respectful and constructive
- Focus on improving skills for the Go community
- Welcome newcomers and help them contribute

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
