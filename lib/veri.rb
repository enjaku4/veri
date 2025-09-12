require_relative "veri/version"

require "active_record"
require "active_support"

require_relative "veri/password/argon2"
require_relative "veri/password/bcrypt"
require_relative "veri/password/scrypt"

require_relative "veri/inputs/base"
require_relative "veri/inputs/authenticatable"
require_relative "veri/inputs/duration"
require_relative "veri/inputs/hashing_algorithm"
require_relative "veri/inputs/model"
require_relative "veri/inputs/non_empty_string"
require_relative "veri/inputs/tenant"
require_relative "veri/configuration"

module Veri
  class Error < StandardError; end
  class InvalidArgumentError < Veri::Error; end
  class ConfigurationError < Veri::InvalidArgumentError; end
  class InvalidTenantError < Veri::InvalidArgumentError; end

  delegate :configure, to: Veri::Configuration
  module_function :configure
end

require_relative "veri/models/session"
require_relative "veri/controllers/concerns/authentication"
require_relative "veri/models/concerns/authenticatable"
require_relative "veri/helpers/migration_helpers"

require_relative "veri/railtie"
