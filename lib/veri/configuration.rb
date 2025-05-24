require "singleton"

module Veri
  class Configuration
    include Singleton

    attr_reader :hashing_algorithm, :inactive_session_lifetime, :total_session_lifetime
    attr_accessor :user_model_name

    def initialize
      @hashing_algorithm = :argon2
      @inactive_session_lifetime = nil
      @total_session_lifetime = 14.days
      @user_model_name = "User"
    end

    def hashing_algorithm=(algorithm)
      @hashing_algorithm = Veri::Inputs.process(algorithm, as: :hashing_algorithm, error: Veri::ConfigurationError)
    end

    def hasher
      case hashing_algorithm
      when :argon2 then Veri::Password::Argon2
      when :bcrypt then Veri::Password::BCrypt
      when :scrypt then Veri::Password::SCrypt
      else raise Veri::Error, "Invalid hashing algorithm: #{hashing_algorithm}"
      end
    end

    def inactive_session_lifetime=(duration)
      @inactive_session_lifetime = Veri::Inputs.process(duration, as: :duration, optional: true, error: Veri::ConfigurationError)
    end

    def total_session_lifetime=(duration)
      @total_session_lifetime = Veri::Inputs.process(duration, as: :duration, error: Veri::ConfigurationError)
    end

    def user_model
      Veri::Inputs.process(user_model_name, as: :model, error: Veri::ConfigurationError)
    end
  end
end
