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

    HASHERS = {
      argon2: Veri::Password::Argon2,
      bcrypt: Veri::Password::BCrypt,
      scrypt: Veri::Password::SCrypt
    }.freeze
    private_constant :HASHERS

    def hasher
      HASHERS.fetch(hashing_algorithm) { raise Veri::Error, "Invalid hashing algorithm: #{hashing_algorithm}" }
    end

    def user_model
      Veri::Inputs.process(user_model_name, as: :model, error: Veri::ConfigurationError)
    end
  end
end
