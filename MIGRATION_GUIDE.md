<!--TODO: discussion-->

# Migration guide to version 3.0.0

Veri v3.0.0 includes several breaking changes. This guide helps you migrate your app from Veri v2.x.x.

If you're new to Veri, simply install the latest version and follow the README instructions.

## Database Migration

Run this migration, replacing `users` with your user table name if it's different:

```rb
class MigrateVeriToV3 < ActiveRecord::Migration[8.1]
  def up
    change_column :veri_sessions, :user_agent, :text

    rename_column :users, :locked, :suspended
    rename_column :users, :locked_at, :suspended_at

    execute "UPDATE users SET hashed_password = CONCAT('argon2:', hashed_password) WHERE hashed_password LIKE '$argon2%'"
    execute "UPDATE users SET hashed_password = CONCAT('bcrypt:', hashed_password) WHERE hashed_password LIKE '$2%'"
    execute "UPDATE users SET hashed_password = CONCAT('pbkdf2:', hashed_password) WHERE hashed_password LIKE 'sha512$%'"
    execute "UPDATE users SET hashed_password = CONCAT('scrypt:', hashed_password) WHERE hashed_password NOT LIKE '%:%'"
  end
end
```

This migration updates the database to be compatible with Veri v3. It changes the `user_agent` column type to `text`, renames the `locked` and `locked_at` columns, and adds an algorithm marker to each stored password hash.

## Account Locking Renamed to Suspension

Account locking is now called suspension, because `lock!` overrode Active Record's row locking method of the same name. Replace any usages of the old methods with their new counterparts:

| Old | New |
|---|---|
| `user.lock!` | `user.suspend!` |
| `user.unlock!` | `user.unsuspend!` |
| `user.locked?` | `user.suspended?` |
| `User.locked` | `User.suspended` |
| `User.unlocked` | `User.unsuspended` |
| `locked` column | `suspended` column |
| `locked_at` column | `suspended_at` column |

The behavior is unchanged.

## Sessions Terminated on Password Update

`update_password` now terminates all of the user's sessions, including the current one. To keep the user signed in, log them in again or opt out of session termination:

```rb
# Update a password and keep the user signed in
user.update_password(new_password)
log_in(user)

# Update a password without terminating sessions
user.update_password(new_password, terminate_sessions: false)
```

## Session as the Source of Truth for the Tenant

The tenant is now passed to `log_in`, and `current_tenant` is a method provided by Veri that returns the tenant of the current session. Remove your `current_tenant` override and pass the tenant when logging in:

```rb
# Before
def current_tenant
  Company.find_by(subdomain: request.subdomain)
end

log_in(user)

# After
log_in(user, tenant: Company.find_by(subdomain: request.subdomain))
```

Veri no longer looks up the session within a tenant, so a session from one tenant is also found on requests for another. If your application relied on that isolation, update its logic to enforce it.
