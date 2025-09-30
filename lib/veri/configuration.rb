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
              Veri::Inputs::HashingAlgorithm.new(
                value,
                error: Veri::ConfigurationError,
                message: "Invalid hashing algorithm `#{value.inspect}`, supported algorithms are: #{Veri::Configuration::HASHERS.keys.join(", ")}"
              ).process
            end
    setting :inactive_session_lifetime,
            default: nil,
            reader: true,
            constructor: -> (value) do
              Veri::Inputs::Duration.new(
                value,
                optional: true,
                error: Veri::ConfigurationError,
                message: "Invalid inactive session lifetime `#{value.inspect}`, expected an instance of ActiveSupport::Duration or nil"
              ).process
            end
    setting :total_session_lifetime,
            default: 14.days,
            reader: true,
            constructor: -> (value) do
              Veri::Inputs::Duration.new(
                value,
                error: Veri::ConfigurationError,
                message: "Invalid total session lifetime `#{value.inspect}`, expected an instance of ActiveSupport::Duration"
              ).process
            end
    setting :user_model_name,
            default: "User",
            reader: true,
            constructor: -> (value) do
              Veri::Inputs::NonEmptyString.new(
                value,
                error: Veri::ConfigurationError,
                message: "Invalid user model name `#{value.inspect}`, expected an ActiveRecord model name as a string"
              ).process
            end

    HASHERS = {
      argon2: Veri::Password::Argon2,
      bcrypt: Veri::Password::BCrypt,
      pbkdf2: Veri::Password::Pbkdf2,
      scrypt: Veri::Password::SCrypt
    }.freeze

    def hasher
      HASHERS.fetch(hashing_algorithm) { raise Veri::Error, "Invalid hashing algorithm: #{hashing_algorithm}" }
    end

    def user_model
      Veri::Inputs::Model.new(
        user_model_name,
        error: Veri::ConfigurationError,
        message: "Invalid user model name `#{user_model_name}`, expected an ActiveRecord model name as a string"
      ).process
    end
  end
end
