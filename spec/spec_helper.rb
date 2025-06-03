ENV["RAILS_ENV"] = "test"

require "byebug"
require "veri"
require "database_cleaner/active_record"
require "action_controller/railtie"
require "rspec/rails"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expose_dsl_globally = true

  config.include ActiveSupport::Testing::TimeHelpers

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
  end

  ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end

    Veri::Configuration.reset_config
  end
end

load "#{File.dirname(__FILE__)}/support/schema.rb"

require "#{File.dirname(__FILE__)}/support/models"
require "#{File.dirname(__FILE__)}/support/application"
require "#{File.dirname(__FILE__)}/support/configuration"
require "#{File.dirname(__FILE__)}/support/controllers"

# TODO: improve everything specs-related
