require "singleton"

module Veri
  class Configuration
    include Singleton

    attr_reader :hashing_algorithm, :inactive_session_lifetime, :total_session_lifetime
    attr_accessor :user_model_name

    def initialize
      @hashing_algorithm = :argon2
      @inactive_session_lifetime = nil
      @total_session_lifetime = 30.days
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

    def inactive_session_lifetime=(duration)
      raise Veri::ConfigurationError, "Configuration `inactive_session_lifetime` must be an instance of ActiveSupport::Duration or nil" unless duration.is_a?(ActiveSupport::Duration) || duration.nil?

      @inactive_session_lifetime = duration
    end

    def total_session_lifetime=(duration)
      raise Veri::ConfigurationError, "Configuration `total_session_lifetime` must be an instance of ActiveSupport::Duration" unless duration.is_a?(ActiveSupport::Duration)

      @total_session_lifetime = duration
    end

    def user_model
      model = user_model_name.try(:safe_constantize)

      raise Veri::ConfigurationError, "Configuration `user_model_name` must be an ActiveRecord model name" unless model && model < ActiveRecord::Base

      model
    end
  end
end
