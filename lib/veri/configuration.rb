require "singleton"

module Veri
  class Configuration
    include Singleton

    attr_reader :hashing_algorithm, :persistent_login_duration, :user_model_name

    def initialize
      @hashing_algorithm = :argon2
      @total_session_lifetime = nil
      @user_model_name = "User"
    end

    def hashing_algorithm=(algorithm)
      raise Veri::ConfigurationError, "Configuration `hashing_algorithm` must be any of the following: :argon2, :bcrypt, :scrypt" unless [:argon2, :bcrypt, :scrypt].include?(algorithm)

      @hashing_algorithm = algorithm
    end

    def hasher
      @hasher ||= case hashing_algorithm
                  when :argon2 then Veri::Password::Argon2
                  when :bcrypt then Veri::Password::BCrypt
                  when :scrypt then Veri::Password::SCrypt
                  else raise Veri::Error, "Invalid hashing algorithm: #{hashing_algorithm}"
                  end
    end

    def total_session_lifetime=(duration)
      raise Veri::ConfigurationError, "Configuration `total_session_lifetime` must be an instance of ActiveSupport::Duration or nil" unless duration.nil? || duration.is_a?(ActiveSupport::Duration)

      @total_session_lifetime = duration
    end

    def user_model_name=(model_name)
      model = model_name.try(:safe_constantize)

      raise Veri::ConfigurationError, "Configuration `user_model_name` must be an ActiveRecord model name" unless model && model < ActiveRecord::Base

      @user_model_name = model_name
    end

    def user_model
      @user_model ||= user_model_name.constantize
    end
  end
end
