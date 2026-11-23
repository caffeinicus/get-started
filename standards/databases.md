# Databases

## PostgreSQL by default

Use PostgreSQL in every environment: development, test, CI, and production. Current major version: **18**.

**Why:** One database means no "works with SQLite locally, breaks on Postgres in prod" surprises. It's also the best-supported database in Rails, Django, and the Node ORMs.

Pick something else only for a recorded reason (for example, a single-file embedded tool where SQLite is the point).

## Local setup on macOS

Postgres comes from Homebrew (`brew install postgresql@18`, `brew services start postgresql@18`).

On a Mac with several user accounts, Homebrew and the Postgres server belong to the **one account that installed Homebrew**. Every other account still uses that same server. It doesn't need its own install. Each account does need:

1. **A Postgres role.** From the Homebrew owner's account:
   ```sh
   createuser --superuser <other-account-name>
   ```
2. **The client tools on its `PATH`.** `postgresql@18` is "keg-only", so `psql` isn't linked by default. Add this to `~/.zshrc`:
   ```sh
   export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"
   ```

`psql` with no arguments connects to a database named after your user, which doesn't exist by default. Use `psql postgres`, or run `createdb` once.

## Migrations

Use the framework's migration-safety checker to catch migrations that lock tables or break running code during a deploy. In Rails that's `strong_migrations`.
