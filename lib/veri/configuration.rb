require "active_support/core_ext/numeric/time"
require "dry-configurable"

module Veri
  module Configuration
    extend Dry::Configurable

    module_function

    setting :hashing_algorithm,
            default: :argon2,
            reader: true,
            constructor: -> (value) do
              Veri::Inputs.process(
                value,
                as: :hashing_algorithm,
                error: Veri::ConfigurationError,
                message: "Invalid hashing algorithm `#{value.inspect}`, supported algorithms are: #{Veri::Configuration::HASHERS.keys.join(", ")}"
              )
            end
    setting :inactive_session_lifetime,
            default: nil,
            reader: true,
            constructor: -> (value) do
              Veri::Inputs.process(
                value,
                as: :duration,
                optional: true,
                error: Veri::ConfigurationError,
                message: "Invalid inactive session lifetime `#{value.inspect}`, expected an instance of ActiveSupport::Duration or nil"
              )
            end
    setting :total_session_lifetime,
            default: 14.days,
            reader: true,
            constructor: -> (value) do
              Veri::Inputs.process(
                value,
                as: :duration,
                error: Veri::ConfigurationError,
                message: "Invalid total session lifetime `#{value.inspect}`, expected an instance of ActiveSupport::Duration"
              )
            end
    setting :user_model_name,
            default: "User",
            reader: true,
            constructor: -> (value) do
              Veri::Inputs.process(
                value,
                as: :non_empty_string,
                error: Veri::ConfigurationError,
                message: "Invalid user model name `#{value.inspect}`, expected an ActiveRecord model name as a string"
              )
            end

    HASHERS = {
      argon2: Veri::Password::Argon2,
      bcrypt: Veri::Password::BCrypt,
      scrypt: Veri::Password::SCrypt
    }.freeze

    def hasher
      HASHERS.fetch(hashing_algorithm) { raise Veri::Error, "Invalid hashing algorithm: #{hashing_algorithm}" }
    end

    def user_model
      Veri::Inputs.process(
        user_model_name,
        as: :model,
        error: Veri::ConfigurationError,
        message: "Invalid user model name `#{user_model_name}`, expected an ActiveRecord model name as a string"
      )
    end
  end
end
