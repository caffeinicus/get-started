# Rails application template. Keep in sync with standards/ruby/rails.md.
#
# Usage (from a shell where `ruby -v` is the version below, via rbenv):
#   rails new my_app -d postgresql --css=tailwind -T -m path/to/template.rb

MIN_RUBY = Gem::Version.new("4.0.10")
ECR = "public.ecr.aws/docker/library" # Docker official images, mirrored on AWS ECR Public
POSTGRES_IMAGE = "#{ECR}/postgres:18"

# --- Guards -------------------------------------------------------------------

if Gem::Version.new(RUBY_VERSION) < MIN_RUBY
  say "Ruby #{MIN_RUBY}+ is required (this is #{RUBY_VERSION}).", :red
  say "  rbenv install #{MIN_RUBY} && rbenv shell #{MIN_RUBY}", :red
  exit 1
end

unless options[:database] == "postgresql"
  say "Use PostgreSQL: rails new ... -d postgresql", :red
  exit 1
end

# --- Ruby version (rbenv) -----------------------------------------------------

create_file ".ruby-version", "#{RUBY_VERSION}\n", force: true

# --- Gems ---------------------------------------------------------------------

gem "pundit"
gem "pagy"
gem "doorkeeper"
gem "strong_migrations"
gem "rswag-api"
gem "rswag-ui"

gem_group :development do
  gem "annotaterb"
  gem "bullet"
  gem "letter_opener_web"
end

gem_group :development, :test do
  gem "rspec-rails"
  gem "rswag-specs"
  gem "factory_bot_rails"
  gem "faker"
  gem "dotenv-rails"
  gem "rubocop-rspec", require: false
  gem "rubocop-rspec_rails", require: false
end

gem_group :test do
  gem "shoulda-matchers"
  gem "webmock"
  gem "simplecov", require: false
end

# --- Setup after `bundle install` ---------------------------------------------

after_bundle do
  # No Minitest, even if -T was forgotten.
  remove_dir "test"
  comment_lines "config/application.rb", %r{require "rails/test_unit/railtie"}

  generate "rspec:install"
  run "bundle binstubs rspec-core" # bin/rspec, used by bin/ci and GitHub Actions
  generate "pundit:install"
  generate "strong_migrations:install"
  generate "annotate_rb:install"

  # Built-in Rails 8 authentication (creates User + Session).
  generate "authentication"

  # --- RSpec ------------------------------------------------------------------

  # SimpleCov must load before the app code.
  prepend_to_file "spec/spec_helper.rb", <<~RUBY
    require "simplecov"
    SimpleCov.start "rails"

  RUBY

  # spec/requests/* gets type: :request automatically (rswag needs it, and the
  # RSpecRails/InferredSpecType cop assumes it).
  uncomment_lines "spec/rails_helper.rb", /config\.infer_spec_type_from_file_location!/

  append_to_file "spec/rails_helper.rb", <<~RUBY

    require "pundit/rspec"
    require "webmock/rspec"
    WebMock.disable_net_connect!(allow_localhost: true)

    Shoulda::Matchers.configure do |config|
      config.integrate do |with|
        with.test_framework :rspec
        with.library :rails
      end
    end

    RSpec.configure do |config|
      config.include FactoryBot::Syntax::Methods
    end
  RUBY

  create_file "spec/factories/users.rb", <<~RUBY, force: true
    FactoryBot.define do
      factory :user do
        sequence(:email_address) { |n| "user\#{n}@example.com" }
        password { "correct-horse-battery-staple" }
      end
    end
  RUBY

  create_file "spec/models/user_spec.rb", <<~RUBY, force: true
    require "rails_helper"

    RSpec.describe User do
      subject(:user) { build(:user) }

      it { is_expected.to have_many(:sessions).dependent(:destroy) }
      it { is_expected.to have_secure_password }

      it "normalizes the email address" do
        user.email_address = "  Ada@Example.COM "
        expect(user.email_address).to eq("ada@example.com")
      end
    end
  RUBY

  # --- Pundit (authorization of records) + Pagy (pagination) -------------------

  inject_into_class "app/controllers/application_controller.rb", "ApplicationController", <<~RUBY.indent(2)
    include Pundit::Authorization
    include Pagy::Method

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  RUBY

  inject_into_file "app/controllers/application_controller.rb", before: /^end\s*\z/ do
    <<~RUBY.indent(2)

      private
        def pundit_user
          Current.user
        end

        def user_not_authorized
          redirect_back_or_to root_path, alert: "You are not authorized to do that."
        end
    RUBY
  end

  create_file "app/policies/user_policy.rb", <<~RUBY
    class UserPolicy < ApplicationPolicy
      def show?
        user.present? && record == user
      end
    end
  RUBY

  create_file "spec/policies/user_policy_spec.rb", <<~RUBY
    require "rails_helper"

    RSpec.describe UserPolicy, type: :policy do
      subject(:policy) { described_class }

      let(:user) { build_stubbed(:user) }

      permissions :show? do
        it "allows users to see themselves" do
          expect(policy).to permit(user, user)
        end

        it "does not allow users to see other users" do
          expect(policy).not_to permit(user, build_stubbed(:user))
        end

        it "does not allow anonymous access" do
          expect(policy).not_to permit(nil, user)
        end
      end
    end
  RUBY

  # --- Doorkeeper (OAuth 2 provider for the API) --------------------------------

  generate "doorkeeper:install"
  generate "doorkeeper:migration"

  # Link tokens and grants to users.
  migration = Dir["db/migrate/*_create_doorkeeper_tables.rb"].first
  gsub_file migration, /^(\s*)# (add_foreign_key :oauth_access_(grants|tokens),)\s*<model>/, '\1\2 :users'
  gsub_file migration, /^\s*# Uncomment below to ensure.*\n/, ""

  # strong_migrations rejects add_foreign_key, but every table here is brand new
  # and empty, so the keys can't block writes. Say so explicitly.
  source = File.read(migration)
  body_start = source.index("  def change\n") + "  def change\n".length
  body_end = source.rindex(/^  end\s*\nend/)
  body = source[body_start...body_end].rstrip.gsub(/^ {4}/, "")
  wrapped = "# Only creates new, empty tables, so the foreign keys can't block writes.\n" \
            "safety_assured do\n#{body.gsub(/^(?=.)/, '  ')}\nend\n"
  File.write(migration, source[0...body_start] + wrapped.gsub(/^(?=.)/, "    ") + source[body_end..])

  create_file "config/initializers/doorkeeper.rb", <<~RUBY, force: true
    Doorkeeper.configure do
      orm :active_record

      # Rails 8 authentication keeps the session id in a signed cookie.
      resource_owner_authenticator do
        Session.find_by(id: cookies.signed[:session_id])&.user || redirect_to(new_session_url)
      end

      grant_flows %w[authorization_code client_credentials]
      force_pkce
      use_refresh_token
      access_token_expires_in 2.hours

      # Store only hashes of tokens and client secrets.
      hash_token_secrets
      hash_application_secrets

      default_scopes :read
      optional_scopes :write
      enforce_configured_scopes
    end
  RUBY

  # OAuth clients are created from the console or seeds, not a public web UI.
  gsub_file "config/routes.rb", /^\s*use_doorkeeper\s*$/, <<~RUBY.indent(2)
    use_doorkeeper do
      skip_controllers :applications, :authorized_applications
    end
  RUBY

  create_file "spec/factories/doorkeeper.rb", <<~RUBY
    FactoryBot.define do
      factory :oauth_application, class: "Doorkeeper::Application" do
        sequence(:name) { |n| "Client \#{n}" }
        redirect_uri { "https://example.com/oauth/callback" }
        scopes { "read" }
      end

      factory :access_token, class: "Doorkeeper::AccessToken" do
        application factory: :oauth_application
        resource_owner_id { association(:user).id }
        scopes { "read" }
        expires_in { 2.hours }
      end
    end
  RUBY

  # --- JSON API (Doorkeeper + Pundit + Pagy) ----------------------------------

  create_file "app/controllers/api/v1/base_controller.rb", <<~RUBY
    module Api
      module V1
        class BaseController < ActionController::API
          include Pundit::Authorization
          include Pagy::Method

          before_action :doorkeeper_authorize!
          after_action :verify_authorized

          rescue_from Pundit::NotAuthorizedError, with: :forbidden
          rescue_from ActiveRecord::RecordNotFound, with: :not_found

          private
            def current_user
              @current_user ||= User.find_by(id: doorkeeper_token&.resource_owner_id)
            end

            def forbidden
              render json: { error: "forbidden" }, status: :forbidden
            end

            def not_found
              render json: { error: "not_found" }, status: :not_found
            end
        end
      end
    end
  RUBY

  create_file "app/controllers/api/v1/me_controller.rb", <<~RUBY
    module Api
      module V1
        class MeController < BaseController
          def show
            authorize current_user, policy_class: UserPolicy
            render json: current_user.as_json(only: %i[id email_address created_at])
          end
        end
      end
    end
  RUBY

  route <<~RUBY
    namespace :api do
      namespace :v1 do
        resource :me, only: :show, controller: :me
      end
    end
  RUBY

  # --- OpenAPI (rswag: specs generate the OpenAPI document) --------------------

  generate "rswag:api:install"
  generate "rswag:ui:install"
  generate "rswag:specs:install"

  create_file "spec/swagger_helper.rb", <<~RUBY, force: true
    require "rails_helper"

    RSpec.configure do |config|
      config.openapi_root = Rails.root.join("openapi").to_s
      config.openapi_format = :yaml
      config.openapi_specs = {
        "v1/openapi.yaml" => {
          openapi: "3.0.3",
          info: { title: "API V1", version: "v1" },
          paths: {},
          components: {
            securitySchemes: {
              bearer: { type: :http, scheme: :bearer, description: "Doorkeeper OAuth 2 access token" }
            }
          },
          security: [ { bearer: [] } ]
        }
      }
    end
  RUBY

  create_file "config/initializers/rswag_api.rb", <<~RUBY, force: true
    Rswag::Api.configure do |c|
      c.openapi_root = Rails.root.join("openapi").to_s
    end
  RUBY

  create_file "config/initializers/rswag_ui.rb", <<~RUBY, force: true
    Rswag::Ui.configure do |c|
      c.openapi_endpoint "/api-docs/v1/openapi.yaml", "API V1"
    end
  RUBY

  create_file "spec/requests/api/v1/me_spec.rb", <<~RUBY
    require "swagger_helper"

    RSpec.describe "API V1 current user" do
      path "/api/v1/me" do
        get "Returns the user the access token belongs to" do
          tags "Users"
          produces "application/json"
          security [ { bearer: [] } ]

          response "200", "the current user" do
            schema type: :object,
              properties: {
                id: { type: :integer },
                email_address: { type: :string, format: :email },
                created_at: { type: :string, format: "date-time" }
              },
              required: %w[id email_address created_at]

            let(:token) { create(:access_token) }
            let(:Authorization) { "Bearer \#{token.plaintext_token}" }

            run_test!
          end

          response "401", "missing or invalid token" do
            let(:Authorization) { "Bearer not-a-real-token" }

            run_test!
          end

          response "403", "token is not tied to a user" do
            let(:token) { create(:access_token, resource_owner_id: nil) }
            let(:Authorization) { "Bearer \#{token.plaintext_token}" }

            run_test!
          end
        end
      end
    end
  RUBY

  # --- RuboCop: Rails omakase + RSpec cops ------------------------------------

  append_to_file ".rubocop.yml", <<~YAML

    plugins:
      - rubocop-rspec
      - rubocop-rspec_rails

    AllCops:
      NewCops: enable
      Exclude:
        - "db/schema.rb"
        - "bin/**/*"
        - "vendor/**/*"
        - "node_modules/**/*"

    # rswag's DSL: `run_test!` is an example; `Authorization` names the header.
    RSpec:
      Language:
        ExampleGroups:
          Regular: [path, get, post, put, patch, delete, response]
        Examples:
          Regular: [run_test!]
    RSpec/VariableName:
      AllowedPatterns: ["^Authorization$"]
    RSpec/EmptyExampleGroup:
      Exclude: ["spec/requests/**/*_spec.rb"]
    RSpec/NestedGroups: # path > verb > response is rswag's standard shape
      Max: 4
  YAML

  # --- Docker images from AWS ECR Public, not Docker Hub ------------------------

  gsub_file "Dockerfile", %r{docker\.io/library/}, "#{ECR}/"
  if File.exist?("config/deploy.yml")
    gsub_file "config/deploy.yml", %r{image: (?:docker\.io/library/)?(mysql|postgres|redis)(?=[:\s])}, "image: #{ECR}/\\1"
    gsub_file "config/deploy.yml", %r{image: valkey/valkey}, "image: public.ecr.aws/valkey/valkey"
  end

  # --- CI: RSpec against Postgres ---------------------------------------------

  if File.exist?(".github/workflows/ci.yml")
    append_to_file ".github/workflows/ci.yml", "\n" + <<~YAML.indent(2)
      test:
        runs-on: ubuntu-latest
        services:
          postgres:
            image: #{POSTGRES_IMAGE}
            env:
              POSTGRES_USER: postgres
              POSTGRES_PASSWORD: postgres
            ports:
              - 5432:5432
            options: --health-cmd="pg_isready" --health-interval=10s --health-timeout=5s --health-retries=3
        env:
          RAILS_ENV: test
          DATABASE_URL: postgres://postgres:postgres@localhost:5432
        steps:
          - name: Checkout code
            uses: actions/checkout@v6

          - name: Set up Ruby
            uses: ruby/setup-ruby@v1
            with:
              bundler-cache: true

          - name: Run specs
            run: bin/rails db:test:prepare && bin/rspec
    YAML
  end

  if File.exist?("config/ci.rb")
    inject_into_file "config/ci.rb", after: /step "Security: Brakeman.*\n/ do
      %(  step "Tests: RSpec", "bin/rspec"\n)
    end
  end

  # --- Dev conveniences ---------------------------------------------------------

  # Bullet: log N+1s and show a footer in dev.
  environment <<~RUBY, env: "development"
    config.after_initialize do
      Bullet.enable = true
      Bullet.rails_logger = true
      Bullet.add_footer = true
    end
  RUBY

  # Letter Opener: deliver mail to the browser in dev.
  environment 'config.action_mailer.delivery_method = :letter_opener_web', env: "development"
  route 'mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?'

  # dotenv: keep .env out of git, commit an example instead.
  append_to_file ".gitignore", "\n.env\n.env.*\n!.env.example\n"
  create_file ".env.example", "# Copy to .env and fill in local values.\n"

  # Generators leave a few style nits; fix them so `bin/rubocop` starts clean.
  run "bin/rubocop --autocorrect"

  git add: "."
  git commit: %(-m "Initial commit from get-started Rails template")
end
