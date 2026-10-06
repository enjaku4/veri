source "https://rubygems.org"

gemspec

rails_version = ENV.fetch("RAILS_VERSION", "~> 7.2")

gem "argon2"
gem "bcrypt"
gem "byebug"
gem "database_cleaner-active_record"
# Rails 7.2.3 and 8.0 pass an option that json 3 no longer accepts.
# Remove once the Rails versions under test work with json 3.
gem "json", "< 3"
gem "rails", rails_version
gem "rake"
gem "rspec"
gem "rspec-rails"
gem "rubocop"
gem "rubocop-md"
gem "rubocop-packaging"
gem "rubocop-performance"
gem "rubocop-rails"
gem "rubocop-rake"
gem "rubocop-rspec"
gem "rubocop-rspec_rails"
gem "rubocop-thread_safety"
gem "scrypt"
gem "sqlite3"
gem "user_agent_parser"
