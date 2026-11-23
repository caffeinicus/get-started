# Quality Gates

Every project, in every language, has three gates. All three must be clean on every commit.

| Gate | What it catches | Standard |
|------|-----------------|----------|
| **Lint** | Style, likely bugs, inconsistent code | No offenses |
| **Security scan** | Vulnerable code patterns, vulnerable dependencies, outdated runtimes | No warnings |
| **Tests** | Broken behavior | No failures |

## Rules

- **Zero, not "fewer".** A gate with 40 known warnings hides the 41st. Fix it, or turn the specific rule off in the config with a comment explaining why.
- **No blanket disables.** Turn off one rule on one line, with a reason (for example `# rubocop:disable Rails/SkipsModelValidations -- bulk import, validated upstream`). Never disable a whole file or category to make a gate pass.
- **One command runs everything locally.** CI runs that same command, so if it passes on your machine it passes in CI.
- **New projects start green.** The project template must generate an app where all three gates already pass.

## Per stack

| Stack | Lint | Security | Tests | Run all |
|-------|------|----------|-------|---------|
| Rails | `bin/rubocop` | `bin/brakeman`, `bin/bundler-audit` | `bin/rspec` | `bin/ci` |
