require "active_support/core_ext/numeric/time"
require "dry-configurable"

module Veri
  module Configuration
    extend Dry::Configurable

    module_function

    setting :hashing_algorithm,
            default: :argon2,
            reader: true,
            constructor: -> (value) { Veri::Inputs.process(value, as: :hashing_algorithm, error: Veri::ConfigurationError) }
    setting :inactive_session_lifetime,
            default: nil,
            reader: true,
            constructor: -> (value) { Veri::Inputs.process(value, as: :duration, optional: true, error: Veri::ConfigurationError) }
    setting :total_session_lifetime,
            default: 14.days,
            reader: true,
            constructor: -> (value) { Veri::Inputs.process(value, as: :duration, error: Veri::ConfigurationError) }
    setting :user_model_name,
            default: "User",
            reader: true,
            constructor: -> (value) { Veri::Inputs.process(value, as: :string, error: Veri::ConfigurationError) }

    def hasher
      case hashing_algorithm
      when :argon2 then Veri::Password::Argon2
      when :bcrypt then Veri::Password::BCrypt
      when :scrypt then Veri::Password::SCrypt
      else raise Veri::Error, "Invalid hashing algorithm: #{hashing_algorithm}"
      end
    end

    def user_model
      Veri::Inputs.process(user_model_name, as: :model, error: Veri::ConfigurationError)
    end
  end
end
