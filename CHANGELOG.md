<!--TODO-->

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
