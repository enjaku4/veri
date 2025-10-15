# Veri: Minimal Authentication for Rails

[![Gem Version](https://badge.fury.io/rb/veri.svg)](http://badge.fury.io/rb/veri)
[![Downloads](https://img.shields.io/gem/dt/veri.svg)](https://rubygems.org/gems/veri)
[![Github Actions badge](https://github.com/enjaku4/veri/actions/workflows/ci.yml/badge.svg)](https://github.com/enjaku4/veri/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/enjaku4/veri.svg)](LICENSE)

Veri is a cookie-based authentication library for Ruby on Rails. Unlike other solutions that generate controllers, views, and mailers for you, Veri provides only essential building blocks giving you complete control over your authentication flow. This approach works well for applications that need custom authentication experiences - instead of modifying existing templates or generated controllers, you build your own interface while Veri handles the complex underlying mechanics of secure password storage and session verification. On top of that, Veri provides multi-tenancy, granular session management, multiple password hashing algorithms, and user impersonation feature.

**Example of Usage:**

Consider a SaaS application where users need to see all their active sessions across different devices and browsers, with the ability to terminate specific sessions remotely. The same session management interface is provided to administrators in their admin panel, giving them visibility into user activity and the ability to terminate user sessions or lock accounts for security reasons. Additionally, administrators have the ability to temporarily assume a user's identity for troubleshooting purposes. All of this can be achieved easily with Veri.

## Table of Contents

**Gem Usage:**
  - [Installation](#installation)
  - [Configuration](#configuration)
  - [Password Management](#password-management)
  - [Controller Integration](#controller-integration)
  - [Authentication Sessions](#authentication-sessions)
  - [Account Lockout](#account-lockout)
  - [Multi-Tenancy](#multi-tenancy)
  - [View Helpers](#view-helpers)
  - [Testing](#testing)

**Community Resources:**
  - [Getting Help and Contributing](#getting-help-and-contributing)
  - [License](#license)
  - [Code of Conduct](#code-of-conduct)

## Installation

Add Veri to your Gemfile:

```rb
gem "veri"
```

Install the gem:

```bash
bundle install
```

Generate the migration for your user model (replace `users` with your user table name if different):

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

## Controller Integration

### Basic Setup

Include the authentication module and configure protection:

```rb
class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication # Require authentication by default
end

class PicturesController < ApplicationController
  skip_authentication only: [:index, :show] # Allow public access to index and show actions
end
```

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

### User Impersonation (Shapeshifting)

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
# Assume another user's identity (maintains original identity)
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

### When Unauthenticated

Override this private method to customize behavior for unauthenticated users:

```rb
class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication

  # ...

  private

  def when_unauthenticated
    # By default, redirects back (HTML) or returns 401 (other formats)
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
```

### Session Information

```rb
session.identity
# => authenticated user

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

# Clean up expired/inactive sessions, and sessions with deleted tenant
Veri::Session.prune

# Clean up expired/inactive sessions for a specific user
user.sessions.prune
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

## Multi-Tenancy

Veri supports multi-tenancy, allowing you to isolate authentication sessions between different tenants such as organizations, clients, or subdomains.

### Setting Up Multi-Tenancy

To enable multi-tenancy, override `current_tenant` method:

```rb
class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication

  private

  def current_tenant
    # Option 1: String-based tenancy (e.g., subdomain)
    request.subdomain

    # Option 2: Model-based tenancy (e.g., organization)
    # Company.find_by(subdomain: request.subdomain)
  end
end
```

### Session Tenant Access

Sessions expose their tenant through `tenant` method:

```rb
# Returns the tenant (string, model instance, or nil in single-tenant applications)
session.tenant
```

### Migration Helpers

Handle tenant changes when models are renamed or removed. These are irreversible data migrations.

```rb
# Rename a tenant class (e.g., when you rename your Organization model to Company)
migrate_authentication_tenant!("Organization", "Company")

# Remove orphaned tenant data (e.g., when you delete the Organization model entirely)
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
