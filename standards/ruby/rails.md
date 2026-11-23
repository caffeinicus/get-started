# Rails Standards

**Baseline:** Rails 8.1 on Ruby 4.0.10+. Builds on [ruby.md](ruby.md) (rbenv, RuboCop, RSpec) and the shared [quality gates](../quality-gates.md), [containers](../containers.md) and [databases](../databases.md) standards.

**Automation:** [templates/rails/template.rb](../../templates/rails/template.rb) applies everything here. It refuses to run on Ruby older than 4.0.10 or with any database other than Postgres.

```sh
rails new my_app -d postgresql --css=tailwind -T \
  -m ~/www/get-started/templates/rails/template.rb
```

| Flag | Why |
|------|-----|
| `-d postgresql` | Postgres everywhere ([databases.md](../databases.md)). |
| `--css=tailwind` | One styling approach across all apps. |
| `-T` | Skips Minitest. The template also deletes `test/` and the test-unit railtie, in case `-T` is forgotten. |

## What we keep from Rails 8 defaults

These come with `rails new`. Don't swap them out without a reason recorded here.

- **Puma** (app server), **Propshaft** (assets), **Importmap** (JS, no Node build step)
- **Hotwire**: Turbo + Stimulus
- **Solid Queue / Solid Cache / Solid Cable**: background jobs, cache and websockets, all backed by the database. No Redis needed.
- **Kamal + Thruster**: deployment
- **Brakeman**, **bundler-audit**, **rubocop-rails-omakase**
- **Authentication**: `bin/rails generate authentication`, the built-in generator, for people signing in to the web app. No Devise.

## Authorization: two layers

| Question | Tool | Where |
|----------|------|-------|
| *Which app or API client is calling, for which user?* | **Doorkeeper** (OAuth 2 provider) | `config/initializers/doorkeeper.rb`, `Api::V1::BaseController` |
| *Is this user allowed to do this to this record?* | **Pundit** (one policy class per model) | `app/policies/` |

Doorkeeper settings, and why:
- **Signs users in through Rails 8 authentication.** The OAuth consent screen uses the same session cookie as the web app.
- **Authorization code + PKCE** for apps acting for a user. **Client credentials** for server-to-server. No implicit or password grants.
- **Token and client secrets stored hashed.** A database leak doesn't leak working tokens.
- **Short-lived access tokens (2h) with refresh tokens.**
- **Scopes:** `read` by default, `write` on request. Unknown scopes are rejected.
- **No public `/oauth/applications` UI.** Clients are created in the console or seeds.

Pundit rules:
- Every API action calls `authorize`. `Api::V1::BaseController` enforces this with `verify_authorized`.
- Index actions use `policy_scope`, so users only ever see records they're allowed to.
- The Pundit user is the token's resource owner in the API, and `Current.user` in web controllers.
- Every policy has a spec in `spec/policies/`, using Pundit's `permissions` matchers.

## API: versioned, documented with OpenAPI

- Routes live under `/api/v1/`, with controllers in `app/controllers/api/v1/` that inherit from `Api::V1::BaseController` (`ActionController::API`, token required).
- Errors are JSON: `401` for no or invalid token, `403` for a Pundit denial, `404` for a missing record.

**rswag** request specs in `spec/requests/api/` test each endpoint and describe it at the same time. This command generates `openapi/v1/openapi.yaml` (OpenAPI 3.0) from them:

```sh
bin/rails rswag:specs:swaggerize
```

Commit the generated file. The interactive docs are served at `/api-docs`. Because the docs come from specs that must pass, they can't silently drift from the code.

## Pagination: Pagy

Pagy 43+. `Pagy::Method` is already included in `ApplicationController` and the API base controller:

```ruby
@pagy, @records = pagy(:offset, policy_scope(Record).order(:id))
```

- **Views:** `@pagy.series_nav`.
- **JSON APIs:** `response.headers.merge!(@pagy.headers_hash)`.
- Always paginate a list endpoint, and always give it an explicit `order`.

Older guides that use `Pagy::Backend` or `Pagy::Frontend` are for Pagy 9 and earlier. That API no longer exists.

## Quality gates

`bin/ci` runs all of these locally. GitHub Actions runs the same checks, plus RSpec against a Postgres 18 service container.

| Command | Standard |
|---------|----------|
| `bin/rubocop` | No offenses. omakase + rubocop-rspec + rubocop-rspec_rails, with new cops enabled. |
| `bin/brakeman` | No warnings. |
| `bin/bundler-audit`, `bin/importmap audit` | No vulnerable gems or JS packages. |
| `bin/rspec` | No failures. |

## Containers

Per [containers.md](../containers.md), the template rewrites the `Dockerfile` (`FROM public.ecr.aws/docker/library/ruby:<version>-slim`), the CI Postgres service, and the image examples in `config/deploy.yml` to use ECR Public.

## Gems we add

Ruby-wide test gems (factory_bot, faker, webmock, simplecov) are listed in [ruby.md](ruby.md#tests-rspec).

| Gem | Group | Purpose |
|-----|-------|---------|
| `pundit` | all | Authorization of records: one policy class per model, plain Ruby. |
| `doorkeeper` | all | OAuth 2 provider for the API. |
| `pagy` | all | Pagination. Fast, small, no monkey-patching. |
| `strong_migrations` | all | Catches unsafe migrations before they reach prod. |
| `rswag-api`, `rswag-ui` | all | Serve the OpenAPI file and interactive docs at `/api-docs`. |
| `annotaterb` | development | Writes the schema as comments at the top of model files. |
| `bullet` | development | Warns about N+1 queries and unused eager loading. |
| `letter_opener_web` | development | Shows sent emails in the browser at `/letter_opener`. |
| `rspec-rails`, `rswag-specs` | dev + test | Tests, and request specs that generate OpenAPI. |
| `factory_bot_rails`, `faker` | dev + test | Test data. |
| `dotenv-rails` | dev + test | Local env vars from `.env` (never committed). Prod uses Rails credentials and Kamal secrets. |
| `rubocop-rspec`, `rubocop-rspec_rails` | dev + test | RSpec style cops on top of omakase. |
| `shoulda-matchers` | test | One-line specs for validations and associations. |
| `webmock`, `simplecov` | test | Block real HTTP calls, and report coverage. |
| `capybara`, `selenium-webdriver` | test | System tests (come with Rails; kept). |

## What a new app starts with

- `GET /api/v1/me`: an example endpoint that uses all of the above. It needs a Doorkeeper token, checks access with `UserPolicy`, and has an rswag spec covering 200, 401 and 403. Copy it when adding endpoints.
- Specs for `User` (shoulda-matchers) and `UserPolicy` (Pundit matchers), with factories for users, OAuth applications and access tokens.
- An initial commit where every gate passes.

## Still to decide

- [ ] Error tracking (Sentry? Honeybadger? AppSignal?)
- [ ] Admin UI (Avo? ActiveAdmin? Build our own?)
- [ ] File uploads storage provider for Active Storage
