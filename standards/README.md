# Standards

Standards are layered. Each layer adds to the one above it and never contradicts it.

| Layer | Applies to | Docs |
|-------|-----------|------|
| **Every project** | All languages and frameworks | [quality-gates.md](quality-gates.md), [containers.md](containers.md), [databases.md](databases.md) |
| **Language** | Everything in that language | [ruby/ruby.md](ruby/ruby.md) |
| **Framework** | Apps built on that framework | [ruby/rails.md](ruby/rails.md) |

Framework docs live in their language's folder, because they inherit its toolchain (version manager, linter, test runner).

## Planned

Add each of these when there's a real project to test it on, not before:

| Language doc | Framework docs |
|--------------|----------------|
| `python/python.md` | `python/django.md` |
| `typescript/typescript.md` | `typescript/react.md` |

## Writing a standard

- **Say why.** A rule with no reason gets ignored or argued about forever.
- **Automate it.** If a template or linter can enforce it, it goes in the template or linter config, and the doc links there.
- **Put it at the highest layer where it's true.** "Use Postgres" is true for every project, so it goes in `databases.md`, not `rails.md`.
