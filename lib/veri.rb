require_relative "veri/version"

require "active_record"
require "active_support"

require_relative "veri/password/argon2"
require_relative "veri/password/bcrypt"
require_relative "veri/password/scrypt"

require_relative "veri/inputs"
require_relative "veri/configuration"

module Veri
  class Error < StandardError; end
  class ConfigurationError < Veri::Error; end
  class InvalidArgumentError < Veri::Error; end

  delegate :configure, to: Veri::Configuration
  module_function :configure
end

require_relative "veri/models/session"
require_relative "veri/controllers/concerns/authentication"
require_relative "veri/models/concerns/authenticatable"

require_relative "veri/railtie"
