## v2.0.0

### Breaking

- Changed `Veri::Session#shapeshift` method signature to accept an optional `tenant:` keyword argument
- `Veri.prune` now deletes only sessions with orphaned tenants and no longer removes inactive or expired sessions

### Features

- Added `Veri::Session#true_tenant` method to fetch the original tenant of a session

### Bugs

- Fixed issue with user impersonation across different tenants

### Misc

- Dropped some unnecessary dependencies

<!--TODO: guide-->
To upgrade to v2.0.0, please refer to the [migration guide](https://github.com/enjaku4/veri/discussions/#)

## v1.1.0

### Features

- Added `Veri::Session.in_tenant` method to fetch sessions for a specific tenant

### Misc

- Added support for Rails 8.1

## v1.0.1

### Bugs

- Fixed tenant validation blocking Rails console and database commands when orphaned tenant classes exist

## v1.0.0

### Breaking

- Dropped support for Rails 7.1

### Features

- Added support for pbkdf2 password hashing algorithm

### Bugs

- Fixed error raised on Rails console commands when the database was not yet set up

## v0.4.0

### Breaking

- Changed `veri_sessions` table to support multi-tenancy
- Renamed `revert_to_true_identity` session method to `to_true_identity`
- Session method `prune` no longer accepts a user argument
- Session method `terminate_all` no longer accepts a user argument

### Features

- Added multi-tenancy support
- Added session scopes to fetch active, expired, and inactive sessions
- Added user scopes to fetch locked and unlocked users

## v0.3.1

### Misc

- Minor improvements and code cleanup
- Relaxed dependency versions

## v0.3.0

### Breaking

- Added account lockout feature

## v0.2.2

### Bugs

- Fixed class resolution in `current_user` method

## v0.2.1

### Misc

- Enhanced error messages
- Performance improvements and code optimizations

## v0.2.0

### Breaking

- Added `password_updated_at` timestamp tracking for authenticatable models
- Added shapeshifter functionality for impersonation/session switching

### Features

- Added `Session#identity` method
- Added `current_session` helper method for views

## v0.1.0

- Initial release
