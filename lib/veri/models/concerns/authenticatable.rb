require "argon2"
require "bcrypt"
require "scrypt"

module Veri
  module Authenticatable
    extend ActiveSupport::Concern

    included do
      raise Veri::Error, "Veri::Authenticatable can only be included once" if defined?(@@included) && @@included != name

      @@included = name

      has_many :veri_sessions, class_name: "Veri::Session", foreign_key: :authenticatable_id, dependent: :destroy
    end

    def update_password(password)
      update!(hashed_password: hasher.create(Veri::Inputs.process(password, as: :string)))
    end

    def verify_password(password)
      hasher.verify(Veri::Inputs.process(password, as: :string), hashed_password)
    end

    private

    def hasher = Veri::Configuration.hasher
  end
end
