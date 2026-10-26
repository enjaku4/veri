# AGENTS.md

A high-level picture of the gem for anyone working on it, including AI agents. What the gem does and how to use it is in README.md; how something is done is in the code.

## Keeping this file current

- When the architecture or a rule changes, update this file in the same change. Replace what no longer holds; don't keep history here, git has it.
- Describe the architecture, not the implementation: leave out details that change with the code.
- Keep entries short.

## Commands

- `bin/setup` installs the dependencies.
- `bin/rspec` runs the specs; `UUID_TESTS=true bin/rspec` runs them against a schema with UUID primary keys.
- `bin/rubocop` runs the linter, including on the README's code examples.
- Both the specs and the linter must pass.

## Code map

- `Veri::Configuration`: the app's settings.
- `Veri::Railtie`: connects Veri to the app. It adds `Veri::Authenticatable` to the configured user model when that model loads, points the session's user associations at it, and makes the migration helpers available.
- `Veri::Authenticatable`: what the user model gets: passwords, suspension and the user's sessions.
- `Veri::Session`: an Active Record model, one record per login. Everything about a session lives here: lifetime, tenant, impersonation, termination.
- `Veri::Authentication`: the controller concern: the session cookie, logging in and out, the `current_*` helpers, and the check that requires a login.
- `Veri::Password`: one adapter per hashing algorithm, all with the same interface.
- `Veri::Events`: publishes events when they are enabled.
- `Veri::Inputs`: check arguments and configuration values where they enter Veri, and raise Veri errors.
- `Veri::MigrationHelpers` and the generator: database setup and data migrations in the app.

The specs run against a dummy Rails app in `spec/support` that really boots and autoloads, so the Railtie is tested the way it runs in an app.

## Invariants

- Veri does nothing at boot that can fail. The app and Rails commands always start, even when the user model or its table doesn't exist yet; problems show up on use.
- An app has one user model.
- A session is found by its cookie alone. The cookie holds a random token and the database stores only its digest, so a leaked database gives no working cookies.
- Only active sessions authenticate.
- A suspended user can't log in and has no sessions left.
- Impersonation happens inside the impersonator's own session: it takes on the other user and tenant and keeps the original ones to return to. An impersonating session can't impersonate again.
- The session is the only source of the tenant.
- Every stored password hash names its algorithm, so the configured algorithm can change at any time.
- Events are published only after the change is committed.

## Boundaries

- Veri provides building blocks, not a finished flow. Whatever depends on how an app works stays in the app: tenant scoping, what happens after login or a password change, what to do with events, test helpers.

## Coding rules

- No defensive programming. Establish the contract and the states the code can actually be in, then write for those. Arguments are checked once, where they enter Veri; the code inside trusts them. When the contract is unclear, find out or ask instead of handling states that may never happen.
- No workarounds. Use only the documented public interface of Rails and every other dependency. When something doesn't work, isn't meant to be used that way, or can't do what's needed, stop and say so: it may mean the approach is wrong.
- Specs test behavior through the public interface, not implementation details. Don't add specs that only repeat another.

## Unfinished work

- TODO comments mark what is still left in the current branch. CI fails on them, so nothing can be released while any remain.
