<!--TODO: v3-->

# Veri: Minimal Authentication for Rails

[![Gem Version](https://badge.fury.io/rb/veri.svg)](http://badge.fury.io/rb/veri)
[![Downloads](https://img.shields.io/gem/dt/veri.svg)](https://rubygems.org/gems/veri)
[![Github Actions badge](https://github.com/enjaku4/veri/actions/workflows/ci.yml/badge.svg)](https://github.com/enjaku4/veri/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/enjaku4/veri.svg)](LICENSE)

Veri is a cookie-based authentication library for Ruby on Rails. It provides only essential building blocks for secure user authentication without cluttering your app with generated controllers, views, and mailers. This makes it ideal for building custom authentication flows.

Veri supports multi-tenancy, granular session management, multiple password hashing algorithms, and provides a user impersonation feature for administration purposes.

**Example of Usage:**

Consider a multi-tenant SaaS application where users need to manage their active sessions across devices and browsers, terminating specific sessions remotely when needed. Administrators require similar capabilities in their admin panel, with additional powers to suspend accounts and temporarily assume user identities for troubleshooting. You can build all this easily with Veri.

## Table of Contents

**Gem Usage:**
  - [Installation](#installation)
  - [Configuration](#configuration)
  - [Password Management](#password-management)
  - [Controller Integration](#controller-integration)
  - [Authentication Sessions](#authentication-sessions)
  - [Account Suspension](#account-suspension)
  - [User Impersonation](#user-impersonation)
  - [Multi-Tenancy](#multi-tenancy)
  - [Events](#events)
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
  # Password hashing algorithm (:argon2, :bcrypt, :pbkdf2, or :scrypt)
  config.hashing_algorithm = :argon2
  # Session inactivity timeout (nil means sessions never expire due to inactivity)
  config.inactive_session_lifetime = nil
  # Maximum session duration regardless of activity
  config.total_session_lifetime = 14.days
  # Your user model name
  config.user_model_name = "User"
  # Publish events
  config.events_enabled = false
end
```

The hashing algorithm can be changed at any time: existing passwords are verified with the algorithm they were hashed with and are automatically re-hashed with the configured algorithm on the next successful login.

## Password Management

Your user model is automatically extended with password management methods:

```rb
# Set or update a password
user.update_password("password")

# Verify a password
user.verify_password("password")

# Check if a password is set
user.password_set?
```

Updating a password terminates all of the user's sessions, including the current one. To keep the user signed in, log them in again or opt out of session termination:

```rb
# Update a password and keep the user signed in
user.update_password(new_password)
log_in(user)

# Update a password without terminating sessions
user.update_password(new_password, terminate_sessions: false)
```

## Controller Integration

### Setup

Include the authentication module in your controllers and configure protection:

```rb
class ApplicationController < ActionController::Base
  include Veri::Authentication

  # Require authentication by default
  with_authentication
end

class PicturesController < ApplicationController
  # Allow public access to index and show actions
  skip_authentication only: [:index, :show]
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

# Authenticates user, returns true on success or false if account is suspended
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

## Authentication Sessions

Veri stores authentication sessions in the database, providing session management capabilities:

### Session Access

```rb
# Get all sessions for a user
user.sessions

# Get current session in controller
current_session

# Get session from a request
Veri::Session.from_request(request)
```

### Sessions Outside Controllers

Code that handles a request outside of controllers, such as Action Cable connections and route constraints, can find the current session from the request:

```rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    # Runs only when the connection opens; disconnecting it after the session is terminated is up to your application
    def connect
      self.current_user = Veri::Session.from_request(request)&.identity || reject_unauthorized_connection
    end
  end
end
```

```rb
# Only administrators can open the jobs dashboard
constraints -> (request) { Veri::Session.from_request(request)&.identity&.admin? } do
  mount Sidekiq::Web => "/jobs"
end
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

When the current session is terminated, the controller still sees it for the rest of the request, so `logged_in?` stays true until the next request unless you call `log_in` or `log_out`. The same applies when a password update or an account suspension terminates it.

## Account Suspension

Veri provides account suspension functionality to temporarily disable user accounts.

```rb
# Suspend a user account
user.suspend!

# Unsuspend a user account
user.unsuspend!

# Check if account is suspended
user.suspended?

# Fetch suspended users
User.suspended

# Fetch unsuspended users
User.unsuspended
```

When an account is suspended, the user cannot log in. If they're already logged in, their sessions are terminated and they are treated as unauthenticated.

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

Veri supports multi-tenancy, allowing you to tie authentication sessions to tenants such as organizations, clients, or subdomains.

### Setup

Pass the tenant when logging a user in:

```rb
# Option 1: String-based tenancy (e.g., subdomain)
log_in(user, tenant: request.subdomain)

# Option 2: Model-based tenancy (e.g., organization)
log_in(user, tenant: company)
```

Tenants can be represented as either a string or an `ActiveRecord` model instance. Without the `tenant:` argument the session has no tenant, which is the single-tenant setup.

Use `current_tenant` in controllers and views to get the tenant of the current session:

```rb
# Returns the tenant (string, model instance, or nil if the session has no tenant)
current_tenant
```

Since `nil` is a valid tenant, `current_tenant` raises an error when no user is logged in.

Veri only stores the tenant in the session and returns it. The session itself is found by its cookie alone, whatever its tenant. How your application uses the tenant, if at all, is entirely up to it, so tenant management and scoping are the application's responsibility.

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

### Switching Tenants

A session belongs to one tenant, and a browser holds one session per host. A user is therefore logged in to one tenant at a time, unless your tenants live on separate subdomains, where each subdomain keeps its own session.

To move a user to another tenant, call `switch_tenant` on their session:

```rb
class CompaniesController < ApplicationController
  def switch
    company = current_user.companies.find(params[:id])

    current_session.switch_tenant(company)

    redirect_to root_path, notice: "Switched to #{company.name}"
  end
end
```

The user stays logged in and the session keeps its expiration. This also covers applications where the tenant is not known at login: log the user in without a tenant and switch once they choose one.

### User Impersonation with Tenants

When using user impersonation in a multi-tenant setup, Veri allows cross-tenant shapeshifting while preserving the original tenant context:

```rb
# Assume another user's identity across tenants
session.shapeshift(user, tenant: company)

# Returns the original tenant when shapeshifted
session.true_tenant
```

The `tenant:` argument always becomes the session's tenant: omitting it means no tenant. In a multi-tenant application, always pass it explicitly.

All other session methods work the same way in multi-tenant applications as in single-tenant applications. However, `to_true_identity` will restore both the original user and tenant.

### Orphaned Sessions

When a tenant object is deleted from your database, its sessions become orphaned. A user with an orphaned session stays logged in, and `current_tenant` raises `Veri::Error` for them.

Terminate the sessions of a tenant as part of the same operation that deletes it:

```rb
Veri::Session.in_tenant(company).terminate_all
company.destroy!
```

If that wasn't done, clean up the orphaned sessions as a fallback:

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

## Events

When `events_enabled` is turned on in the configuration, Veri publishes events for security-relevant operations, for example to build an audit trail. Events are published with `ActiveSupport::Notifications` once the change is committed. Subscribe to the ones you need:

```rb
ActiveSupport::Notifications.subscribe("terminate_session.veri") do |event|
  AuditLog.create!(
    action: "terminate_session",
    user: event.payload[:session].identity,
    actor: event.payload[:actor]
  )
end
```

| Event | Payload |
|---|---|
| `establish_session.veri` | `session`, `actor` |
| `terminate_session.veri` | `session`, `actor` |
| `switch_tenant.veri` | `session`, `actor`, `previous_tenant` |
| `change_password.veri` | `identity`, `actor` |
| `suspend_account.veri` | `identity`, `actor` |
| `unsuspend_account.veri` | `identity`, `actor` |
| `start_impersonation.veri` | `session`, `actor` |
| `end_impersonation.veri` | `session`, `actor`, `impersonated_identity`, `impersonated_tenant` |

Every method that emits events takes an optional actor: whatever your application wants to record as the one who performed the operation, even a plain string like `"cleanup job"`. Model methods default to `nil`, `log_in` to the login identity, and `log_out` to the session's `true_identity`. All defaults can be overridden:

```rb
# The user changes their own password
current_user.update_password(new_password, actor: current_user)

# An administrator suspends an account
user.suspend!(actor: admin)

# The user logs out; by default, the actor is the user themselves
log_out

# A cleanup job removes expired sessions
Veri::Session.expired.terminate_all(actor: "cleanup job")
```

When several sessions are terminated at once, for example with `terminate_all`, `suspend!` or `update_password`, Veri publishes one `terminate_session.veri` event per session. Keep this in mind when terminating a large number of sessions, as each of them produces an event.

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

### Sessions as Test Data

Code that receives a session, such as a service object that terminates all sessions but the current one, can be tested without logging in. Create the session directly:

```rb
module SessionHelpers
  def create_session(user, expires_at:, last_seen_at:, tenant: nil, ip_address: nil, user_agent: nil)
    session = Veri::Session.create!(
      authenticatable: user,
      expires_at:,
      last_seen_at:,
      hashed_token: SecureRandom.hex,
      ip_address:,
      user_agent:
    )
    session.switch_tenant(tenant)
    session
  end
end

# In your spec_helper.rb
RSpec.configure do |config|
  config.include SessionHelpers
end
```

## Getting Help and Contributing

### Getting Help

Have a question or need assistance? Open a discussion in the [discussions section](https://github.com/enjaku4/veri/discussions) for:

- Usage questions
- Implementation guidance
- Open-ended ideas or suggestions

### Issues

[Issues](https://github.com/enjaku4/veri/issues) track bugs, planned features, and other work. When reporting a bug, please include:

- A clear description of the problem
- Steps to reproduce the issue
- Your environment details (Rails and Ruby versions, OS, etc.)

### Contributing Code

Any open issue is free to pick up or discuss. Check the [project board](https://github.com/users/enjaku4/projects/13) or [issues tab](https://github.com/enjaku4/veri/issues).

Before contributing, please read the [contributing guidelines](https://github.com/enjaku4/veri/blob/main/CONTRIBUTING.md).

## License

The gem is available as open source under the terms of the [MIT License](https://github.com/enjaku4/veri/blob/main/LICENSE.txt).

## Code of Conduct

Everyone interacting in the Veri project is expected to follow the [code of conduct](https://github.com/enjaku4/veri/blob/main/CODE_OF_CONDUCT.md).

## Old Versions

Only the latest major version is actively maintained. READMEs for older versions are available here for reference:

[v2.x.x](https://github.com/enjaku4/veri/blob/e6909d2689c2ae11919fc3d1f3c50c19b2995a91/README.md) | [v1.x.x](https://github.com/enjaku4/veri/blob/9c188e16a703141b7cd89dd31d5cd49a557f143d/README.md)
