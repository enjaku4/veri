require "active_support/core_ext/numeric/time"
require "singleton"

module Veri
  class Configuration
    include Singleton

    attr_reader :hashing_algorithm, :inactive_session_lifetime, :total_session_lifetime, :user_model_name

    def initialize
      reset_to_defaults!
    end

    def hashing_algorithm=(value)
      @hashing_algorithm = Veri::Inputs::HashingAlgorithm.new(
        value,
        error: Veri::ConfigurationError,
        message: "Invalid hashing algorithm `#{value.inspect}`, supported algorithms are: #{HASHERS.keys.join(", ")}"
      ).process
    end

    def inactive_session_lifetime=(value)
      @inactive_session_lifetime = Veri::Inputs::Duration.new(
        value,
        optional: true,
        error: Veri::ConfigurationError,
        message: "Invalid inactive session lifetime `#{value.inspect}`, expected an instance of ActiveSupport::Duration or nil"
      ).process
    end

    def total_session_lifetime=(value)
      @total_session_lifetime = Veri::Inputs::Duration.new(
        value,
        error: Veri::ConfigurationError,
        message: "Invalid total session lifetime `#{value.inspect}`, expected an instance of ActiveSupport::Duration"
      ).process
    end

    def user_model_name=(value)
      @user_model_name = Veri::Inputs::NonEmptyString.new(
        value,
        error: Veri::ConfigurationError,
        message: "Invalid user model name `#{value.inspect}`, expected an ActiveRecord model name as a string"
      ).process
    end

    def reset_to_defaults!
      self.hashing_algorithm = :argon2
      self.inactive_session_lifetime = nil
      self.total_session_lifetime = 14.days
      self.user_model_name = "User"
    end

    HASHERS = {
      argon2: Veri::Password::Argon2,
      bcrypt: Veri::Password::BCrypt,
      pbkdf2: Veri::Password::Pbkdf2,
      scrypt: Veri::Password::SCrypt
    }.freeze
    private_constant :HASHERS

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

    def configure
      yield self
    end

    class << self
      delegate :hashing_algorithm, :inactive_session_lifetime, :total_session_lifetime, :user_model_name,
               :hashing_algorithm=, :inactive_session_lifetime=, :total_session_lifetime=, :user_model_name=,
               :hasher, :user_model, :reset_to_defaults!, :configure,
               to: :instance
    end
  end
end
