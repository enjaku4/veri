# Veri: Minimal Authentication for Rails

[![Gem Version](https://badge.fury.io/rb/veri.svg)](http://badge.fury.io/rb/veri)
[![Downloads](https://img.shields.io/gem/dt/veri.svg)](https://rubygems.org/gems/veri)
[![Github Actions badge](https://github.com/enjaku4/veri/actions/workflows/ci.yml/badge.svg)](https://github.com/enjaku4/veri/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/enjaku4/veri.svg)](LICENSE)

Veri is a cookie-based authentication library for Ruby on Rails. It provides only essential building blocks for secure user authentication without cluttering your app with generated controllers, views, and mailers. This makes it ideal for building custom authentication flows.

Veri supports multi-tenancy, granular session management, multiple password hashing algorithms, and provides a user impersonation feature for administration purposes.

**Example of Usage:**

Consider a multi-tenant SaaS application where users need to manage their active sessions across devices and browsers, terminating specific sessions remotely when needed. Administrators require similar capabilities in their admin panel, with additional powers to lock accounts and temporarily assume user identities for troubleshooting. You can build all this easily with Veri.

## Table of Contents

**Gem Usage:**
  - [Installation](#installation)
  - [Configuration](#configuration)
  - [Password Management](#password-management)
  - [Controller Integration](#controller-integration)
  - [Authentication Sessions](#authentication-sessions)
  - [Account Lockout](#account-lockout)
  - [User Impersonation](#user-impersonation)
  - [Multi-Tenancy](#multi-tenancy)
  - [View Helpers](#view-helpers)
  - [Testing](#testing)

**Community Resources:**
  - [Getting Help and Contributing](#getting-help-and-contributing)
  - [License](#license)
  - [Code of Conduct](#code-of-conduct)
  - [Old Versions](#old-versions)

## Installation

Add Veri to your Gemfile:

```rb
gem "veri"
```

Install the gem:

```shell
bundle install
```

Generate the migration for your user model (replace `users` with your table name if different):

```shell
# For standard integer IDs
rails generate veri:authentication users

# For UUID primary keys
rails generate veri:authentication users --uuid
```

Run the migration:

```shell
rails db:migrate
```

## Configuration

Configure Veri in an initializer if customization is needed:

```rb
# These are the default values; you can change them as needed
Veri.configure do |config|
  config.hashing_algorithm = :argon2       # Password hashing algorithm (:argon2, :bcrypt, :pbkdf2, or :scrypt)
  config.inactive_session_lifetime = nil   # Session inactivity timeout (nil means sessions never expire due to inactivity)
  config.total_session_lifetime = 14.days  # Maximum session duration regardless of activity
  config.user_model_name = "User"          # Your user model name
end
```

## Password Management

Your user model is automatically extended with password management methods:

```rb
# Set or update a password
user.update_password("password")

# Verify a password
user.verify_password("password")
```
Changing a password does not automatically terminate existing sessions. If you want to invalidate the user's sessions after a password change, do so explicitly:

```rb
user.update_password(new_password)
user.sessions.terminate_all
```

## Controller Integration

### Setup

Include the authentication module in your controllers and configure protection:

```rb
class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication # Require authentication by default
end

class PicturesController < ApplicationController
  skip_authentication only: [:index, :show] # Allow public access to index and show actions
end
```

Both `with_authentication` and `skip_authentication` work exactly the same as Rails' `before_action` and `skip_before_action` methods.

### Authentication Methods

This is a simplified example of how to use Veri's authentication methods:

```rb
class RegistrationsController < ApplicationController
  skip_authentication

  def create
    user = User.new(user_params)

    if user.valid?
      user.update_password(user_params[:password])
      log_in(user)
      redirect_to dashboard_path
    else
      render :new, status: :unprocessable_content
    end
  end
end

class SessionsController < ApplicationController
  skip_authentication except: [:destroy]

  def create
    user = User.find_by(email: params[:email])

    if user&.verify_password(params[:password])
      log_in(user)
      redirect_to return_path || dashboard_path
    else
      flash.now[:alert] = "Invalid credentials"
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    log_out
    redirect_to root_path
  end
end
```

Available controller methods:

```rb
# Returns authenticated user or nil
current_user

# Returns true if user is authenticated
logged_in?

# Authenticates user and creates session, returns true on success or false if account is locked
log_in(user)

# Terminates current session
log_out

# Returns path user was trying to access before authentication, if any
return_path

# Returns current authentication session
current_session
```

### When Unauthenticated

By default, when unauthenticated, Veri redirects back (HTML) or returns 401 (other formats). Override this private method to customize behavior for unauthenticated users:

```rb
class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication

  private

  def when_unauthenticated
    redirect_to login_path
  end
end
```

The `when_unauthenticated` method can be overridden in any controller to provide controller-specific handling.

## Authentication Sessions

Veri stores authentication sessions in the database, providing session management capabilities:

### Session Access

```rb
# Get all sessions for a user
user.sessions

# Get current session in controller
current_session
```

### Session Information

```rb
# Get the authenticated user
session.identity

# Get session details
session.info
# => {
#   device: "Desktop",
#   os: "macOS",
#   browser: "Chrome",
#   ip_address: "1.2.3.4",
#   last_seen_at: "2023-10-01 12:00:00"
# }
```

### Session Status

```rb
# Session is active (neither expired nor inactive)
session.active?

# Session exceeded inactivity timeout
session.inactive?

# Session exceeded maximum lifetime
session.expired?

# Fetch active sessions
Veri::Session.active

# Fetch inactive sessions
Veri::Session.inactive

# Fetch expired sessions
Veri::Session.expired
```

### Session Management

```rb
# Terminate a specific session
session.terminate

# Terminate all sessions
Veri::Session.terminate_all

# Terminate all sessions for a specific user
user.sessions.terminate_all

# Clean up inactive sessions for a specific user
user.sessions.inactive.terminate_all

# Clean up expired sessions globally
Veri::Session.expired.terminate_all
```

## Account Lockout

Veri provides account lockout functionality to temporarily disable user accounts.

```rb
# Lock a user account
user.lock!

# Unlock a user account
user.unlock!

# Check if account is locked
user.locked?

# Fetch locked users
User.locked

# Fetch unlocked users
User.unlocked
```

When an account is locked, the user cannot log in. If they're already logged in, their sessions are terminated and they are treated as unauthenticated.

## User Impersonation

Veri provides user impersonation functionality that allows administrators to temporarily assume another user's identity:

```rb
module Admin
  class ImpersonationController < ApplicationController
    def create
      user = User.find(params[:user_id])
      current_session.shapeshift(user)
      redirect_to root_path, notice: "Now viewing as #{user.name}"
    end

    def destroy
      original_user = current_session.true_identity
      current_session.to_true_identity
      redirect_to admin_dashboard_path, notice: "Returned to #{original_user.name}"
    end
  end
end
```

Available session methods:

```rb
# Assume another user's identity (in single-tenant applications)
session.shapeshift(user)

# Return to original identity
session.to_true_identity

# Returns true if currently shapeshifted
session.shapeshifted?

# Returns original user when shapeshifted, otherwise current user
session.true_identity
```

Controller helper:

```rb
# Returns true if the current session is shapeshifted
shapeshifter?
```

## Multi-Tenancy

Veri supports multi-tenancy, allowing you to isolate authentication sessions between different tenants such as organizations, clients, or subdomains.

### Setup

To isolate authentication sessions between different tenants, override the `current_tenant` method:

```rb
class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication

  private

  def current_tenant
    # Option 1: String-based tenancy (e.g., subdomain)
    request.subdomain

    # Option 2: Model-based tenancy (e.g., organization)
    Company.find_by(subdomain: request.subdomain)
  end
end
```

By default, Veri assumes a single-tenant setup where `current_tenant` returns `nil`. Tenants can be represented as either a string or an `ActiveRecord` model instance.

### Session Tenant Access

Sessions expose their tenant through the `tenant` method:

```rb
# Returns the tenant (string, model instance, or nil in single-tenant applications)
session.tenant
```

To manage sessions for a specific tenant:

```rb
# Fetch all sessions for a given tenant
Veri::Session.in_tenant(tenant)

# Fetch sessions for a specific user within a tenant
user.sessions.in_tenant(tenant)

# Terminate all sessions for a specific user within a tenant
user.sessions.in_tenant(tenant).terminate_all
```

### User Impersonation with Tenants

When using user impersonation in a multi-tenant setup, Veri allows cross-tenant shapeshifting while preserving the original tenant context:

```rb
# Assume another user's identity across tenants
session.shapeshift(user, tenant: company)

# Returns the original tenant when shapeshifted
session.true_tenant
```

All other session methods work the same way in multi-tenant applications as in single-tenant applications. However, `to_true_identity` will restore both the original user and tenant.

### Orphaned Sessions

When a tenant object is deleted from your database, its associated sessions become orphaned.

To clean up orphaned sessions, use:

```rb
Veri::Session.prune
```

### Tenant Migrations

When you rename or remove models used as tenants, you need to update Veri's stored data accordingly. Use these irreversible data migrations:

```rb
# Rename a tenant class (e.g., when you rename your Organization model to Company)
migrate_authentication_tenant!("Organization", "Company")

# Remove tenant data (e.g., when you delete the Organization model entirely)
delete_authentication_tenant!("Organization")
```

## View Helpers

Access authentication state in your views:

```erb
<% if logged_in? %>
  <p>Welcome, <%= current_user.name %>!</p>
  <% if shapeshifter? %>
    <p><em>Currently viewing as <%= current_user.name %> (Original: <%= current_session.true_identity.name %>)</em></p>
    <%= link_to "Return to Original Identity", revert_path, method: :patch %>
  <% end %>
  <%= link_to "Logout", logout_path, method: :delete %>
<% else %>
  <%= link_to "Login", login_path %>
<% end %>
```

## Testing

Veri doesn't include test helpers, but you can easily create your own:

### Request Specs (Recommended)

```rb
module AuthenticationHelpers
  def log_in(user)
    password = "test_password"
    user.update_password(password)
    post login_path, params: { email: user.email, password: }
  end

  def log_out
    delete logout_path
  end
end

# In your spec_helper.rb
RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
```

### Controller Specs (Legacy)

```rb
module AuthenticationHelpers
  def log_in(user)
    controller.log_in(user)
  end

  def log_out
    controller.log_out
  end
end

# In your spec_helper.rb
RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :controller
end
```

## Getting Help and Contributing

### Getting Help
Have a question or need assistance? Open a discussion in our [discussions section](https://github.com/enjaku4/veri/discussions) for:
- Usage questions
- Implementation guidance
- Feature suggestions

### Reporting Issues
Found a bug? Please [create an issue](https://github.com/enjaku4/veri/issues) with:
- A clear description of the problem
- Steps to reproduce the issue
- Your environment details (Rails version, Ruby version, etc.)

### Contributing Code
Ready to contribute? You can:
- Fix bugs by submitting pull requests
- Improve documentation
- Add new features (please discuss first in our [discussions section](https://github.com/enjaku4/veri/discussions))

Before contributing, please read the [contributing guidelines](https://github.com/enjaku4/veri/blob/main/CONTRIBUTING.md)

## License

The gem is available as open source under the terms of the [MIT License](https://github.com/enjaku4/veri/blob/main/LICENSE.txt).

## Code of Conduct

Everyone interacting in the Veri project is expected to follow the [code of conduct](https://github.com/enjaku4/veri/blob/main/CODE_OF_CONDUCT.md).

## Old Versions

Only the latest major version is supported. Older versions are obsolete and not maintained, but their READMEs are available here for reference:

[v1.x.x](https://github.com/enjaku4/veri/blob/9c188e16a703141b7cd89dd31d5cd49a557f143d/README.md)
