# Ruby Standards

Applies to every Ruby project. Rails apps add [rails.md](rails.md) on top of this.

## Version: 4.0.10 or newer

**Why:** Ruby 4.0.9 and earlier have a critical remote code execution vulnerability (CVE-2026-132825). Brakeman fails any app running on them.

Every project pins its exact version in `.ruby-version`.

## Version manager: rbenv

Use **rbenv**. Never the system Ruby, and no rvm, asdf, or chruby. One tool means one set of instructions that works for everyone.

```sh
brew upgrade ruby-build          # new Ruby releases need a current ruby-build
rbenv install 4.0.10
rbenv shell 4.0.10               # or `rbenv local 4.0.10` inside a project
```

**On a Mac with several user accounts:** Homebrew belongs to the account that installed it, so run `brew upgrade ruby-build` from that account. Then run `rbenv install` from your own account. Rubies install into your own `~/.rbenv`, so each account installs the versions it needs.

## Style: RuboCop

- Base config: **rubocop-rails-omakase** for Rails apps, or plain RuboCop for other projects.
- Add **rubocop-rspec** wherever RSpec is used.
- Turn on new cops (`AllCops: NewCops: enable`), so upgrades don't quietly skip new checks.
- The [quality-gates](../quality-gates.md) rules apply: no offenses, and no blanket disables.

## Tests: RSpec

Use **RSpec**, not Minitest, in every Ruby project.

**Why:** It's one test style and one set of matchers across all projects, with the best ecosystem support (shoulda-matchers, Pundit and rswag matchers, factory_bot).

Minitest may still show up in `Gemfile.lock`, because ActiveSupport depends on it. That's fine as long as nothing in the project requires it.

| Gem | Purpose |
|-----|---------|
| `rspec` / `rspec-rails` | Test framework |
| `factory_bot` / `factory_bot_rails` | Test data |
| `faker` | Realistic fake values |
| `webmock` | Blocks real HTTP calls in tests |
| `simplecov` | Coverage report in `coverage/` |

## Dependencies

- Commit `Gemfile.lock`.
- Run `bundler-audit` in CI so gems with known CVEs fail the build.
