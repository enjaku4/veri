require "argon2"
require "bcrypt"
require "scrypt"

module Veri
  module Authenticatable
    extend ActiveSupport::Concern

    included do
      raise Veri::Error, "Veri::Authenticatable can only be included once" if defined?(@@included) && @@included != name

      @@included = name
    end

    def update_password(password)
      validate_password(password)

      update!(hashed_password: hasher.create(password))
    end

    def verify_password(password)
      validate_password(password)

      hasher.verify(password, hashed_password)
    end

    private

    def hasher = Veri::Configuration.instance.hasher

    def validate_password(password)
      raise Veri::InvalidArgumentError, "Password must be a string" unless password.is_a?(String)
    end
  end
end
