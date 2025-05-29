# Veri: Minimal Authentication Framework for Rails

[![Gem Version](https://badge.fury.io/rb/veri.svg)](http://badge.fury.io/rb/veri)
[![Github Actions badge](https://github.com/brownboxdev/veri/actions/workflows/ci.yml/badge.svg)](https://github.com/brownboxdev/veri/actions/workflows/ci.yml)

Veri is a cookie-based authentication library for Ruby on Rails that provides essential authentication building blocks without imposing business logic. Unlike full-featured solutions, Veri gives you complete control over your authentication flow while handling the complex underlying mechanics of secure password storage and session management.

**Key Features:**

- Cookie-based authentication with database-stored sessions
- Supports multiple password hashing algorithms (argon2, bcrypt, scrypt)
- Granular session management and control
- Flexible authentication callbacks
- No pre-defined business logic, no views, controllers, or mailers — just the essential methods
- Built-in return path handling

> ⚠️ **Development Notice**<br>
> Veri is functional but in early development. Breaking changes may occur in minor releases until v1.0!

## Table of Contents

**Gem Usage:**
  - [Installation](#installation)
  - [Configuration](#configuration)
  - [Password Management](#password-management)
  - [Controller Integration](#controller-integration)
  - [Authentication Sessions](#authentication-sessions)
  - [View Helpers](#view-helpers)
  - [Testing](#testing)

**Community Resources:**
  - [Contributing](#contributing)
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

If customization is required, configure Veri in an initializer:

```rb
# These are the default values; you can change them as needed
Veri.configure do |config|
  config.hashing_algorithm = :argon2       # Password hashing algorithm (:argon2, :bcrypt, or :scrypt)
  config.inactive_session_lifetime = nil   # Session inactivity timeout (nil means sessions never expire due to inactivity)
  config.total_session_lifetime = 14.days  # Maximum session duration regardless of activity
  config.user_model_name = "User"          # Your user model name
end
```

## Password Management

Your user model is automatically extended with password management methods:

```rb
# Set or update a password
user.update_password("new_password")

# Verify a password
user.verify_password("submitted_password")
```

## Controller Integration

### Basic Setup

Include the authentication module and configure protection:

```rb
class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication  # Require authentication by default
end

class PicturesController < ApplicationController
  skip_authentication only: [:index, :show]  # Allow public access to index and show actions
end
```

### Authentication Methods

This is a simplified example of how to use Veri's authentication methods in your controllers:

```rb
class SessionsController < ApplicationController
  skip_authentication except: [:destroy]

  def create
    user = User.find_by(email: params[:email])

    if user&.verify_password(params[:password])
      log_in(user)
      redirect_to return_path || dashboard_path
    else
      flash.now[:alert] = "Invalid credentials"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    log_out
    redirect_to root_path
  end
end
```

Available methods:

- `current_user` - returns the authenticated user or `nil`
- `logged_in?` - returns `true` if user is authenticated
- `log_in(user)` - authenticates the user and creates a session
- `log_out` - terminates the current session
- `return_path` - returns the path the user was trying to access before authentication
- `current_session` - returns the current authentication session

### Authentication Callbacks

Override these private methods to customize authentication behavior:

```rb
class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication

  # ...

  private

  # Called after successful login
  def after_login(user)
    Rails.logger.info "User #{user.id} logged in"
    # Custom redirect logic, analytics, etc.
  end

  # Called after logout
  def after_logout
    Rails.logger.info "User logged out"
    # Cleanup, analytics, etc.
  end

  # Customize unauthenticated user handling
  def when_unauthenticated
    # By default redirects back with a fallback to the root path if the request format is HTML,
    # otherwise responds with 401 Unauthorized
    redirect_to login_path
  end
end
```

## Authentication Sessions

Veri stores authentication sessions in the database, enabling powerful session management:

### Session Access

```rb
# Get all sessions for a user
user.veri_sessions

# Get current session in controller
current_session
```

### Session Information

```rb
session.info
# => {
#   device: "Desktop",
#   os: "macOS",
#   browser: "Chrome",
#   ip_address: "1.2.3.4",
#   last_activity: "2023-10-01 12:00:00"
# }
```

### Session Status

```rb
session.active?     # Session is active (neither expired nor inactive)
session.inactive?   # Session exceeded inactivity timeout
session.expired?    # Session exceeded maximum lifetime
```

### Session Management

```rb
# Terminate a specific session
session.terminate

# Terminate all sessions for a user
Veri::Session.terminate_all(user)

# Clean up expired/inactive sessions
Veri::Session.prune           # All sessions
Veri::Session.prune(user)     # Specific user's sessions
```

## View Helpers

Access authentication state in your views:

```erb
<% if logged_in? %>
  <p>Welcome, <%= current_user.name %>!</p>
  <%= link_to "Logout", logout_path, method: :delete %>
<% else %>
  <%= link_to "Login", login_path %>
<% end %>
```

## Testing

Veri doesn't provide test helpers, but you can easily create your own:

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

## Contributing

### Getting Help
Have a question or need assistance? Open a discussion in our [discussions section](https://github.com/brownboxdev/veri/discussions) for:
- Usage questions
- Implementation guidance
- Feature suggestions

### Reporting Issues
Found a bug? Please [create an issue](https://github.com/brownboxdev/veri/issues) with:
- A clear description of the problem
- Steps to reproduce the issue
- Your environment details (Rails version, Ruby version, etc.)

### Contributing Code
Ready to contribute? You can:
- Fix bugs by submitting pull requests
- Improve documentation
- Add new features (please discuss first in our [discussions section](https://github.com/brownboxdev/veri/discussions))

Before contributing, please read the [contributing guidelines](https://github.com/brownboxdev/veri/blob/master/CONTRIBUTING.md)

## License

The gem is available as open source under the terms of the [MIT License](https://github.com/brownboxdev/veri/blob/main/LICENSE.txt).

## Code of Conduct

Everyone interacting in the Veri project is expected to follow the [code of conduct](https://github.com/brownboxdev/veri/blob/main/CODE_OF_CONDUCT.md).
