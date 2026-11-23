# get-started

The single source of truth for how we start and build projects. If it's a default we've agreed on, it lives here.

## Layout

```
standards/      What we've agreed on, and why. Layered: every project, then language, then framework.
  quality-gates.md  containers.md  databases.md
  ruby/         ruby.md, rails.md   (later: python/, typescript/)
templates/      Generators that apply the standards to a new project, one folder per framework.
  rails/template.rb
```

Standards and templates are kept in separate trees. A framework doc can use several language and shared docs. See [standards/README.md](standards/README.md) for how the layers fit together.

## Starting a new Rails app

```sh
rbenv install 4.0.10 && rbenv shell 4.0.10   # Ruby 4.0.10+ via rbenv
gem install rails
rails new my_app -d postgresql --css=tailwind -T \
  -m ~/www/get-started/templates/rails/template.rb
```

That gives you every default from [standards/ruby/rails.md](standards/ruby/rails.md), already installed and configured: Pundit, Doorkeeper, Pagy, rswag/OpenAPI, RSpec, and no Minitest. `bin/rubocop` and `bin/brakeman` start clean, and once Postgres is running, `bin/rails db:prepare && bin/rspec` passes.

## Changing a standard

1. Edit the doc **and** the template in the same commit, so they never drift apart.
2. Say *why* in the doc. A standard with no reason gets ignored.
3. Put the rule at the highest layer where it's true (shared, then language, then framework).
4. Existing apps aren't updated automatically. Upgrade them on purpose.
