module Veri
  module Authenticatable
    extend ActiveSupport::Concern

    included do
      raise Veri::Error, "Veri::Authenticatable can only be included once" if defined?(@@included) && @@included != name

      @@included = name

      has_many :veri_sessions, class_name: "Veri::Session", foreign_key: :authenticatable_id, dependent: :destroy

      scope :locked, -> { where(locked: true) }
      scope :unlocked, -> { where(locked: false) }
    end

    def update_password(password)
      update!(
        hashed_password: hasher.create(
          Veri::Inputs::NonEmptyString.new(password, message: "Expected a non-empty string, got `#{password.inspect}`").process
        ),
        password_updated_at: Time.current
      )
    end

    def verify_password(password)
      hasher.verify(
        Veri::Inputs::NonEmptyString.new(password, message: "Expected a non-empty string, got `#{password.inspect}`").process,
        hashed_password
      )
    end

    def lock!
      update!(locked: true, locked_at: Time.current)
    end

    def unlock!
      update!(locked: false, locked_at: nil)
    end

    private

    def hasher
      @hasher ||= Veri::Configuration.hasher
    end
  end
end
