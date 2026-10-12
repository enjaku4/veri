module Veri
  module Authenticatable
    extend ActiveSupport::Concern

    included do
      raise Veri::Error, "Veri::Authenticatable can only be included once" if defined?(@@included) && @@included != name

      @@included = name

      has_many :sessions, class_name: "Veri::Session", foreign_key: :authenticatable_id, dependent: :destroy

      scope :suspended, -> { where(suspended: true) }
      scope :unsuspended, -> { where(suspended: false) }
    end

    def update_password(password)
      update!(
        hashed_password: hasher.create(
          Veri::Inputs::NonEmptyString.new(password).process
        ),
        password_updated_at: Time.current
      )
    end

    def password_set?
      hashed_password.present?
    end

    def verify_password(password)
      processed_password = Veri::Inputs::NonEmptyString.new(password).process

      return false unless password_set?

      stored_hasher = Veri::Configuration::HASHERS.values.find { _1.match?(hashed_password) }

      raise Veri::Error, "Unrecognized password hash format" unless stored_hasher

      return false unless stored_hasher.verify(processed_password, hashed_password)

      update_column(:hashed_password, hasher.create(processed_password)) unless stored_hasher == hasher

      true
    end

    def suspend!
      transaction do
        update!(suspended: true, suspended_at: Time.current)
        sessions.terminate_all
      end
    end

    def unsuspend!
      update!(suspended: false, suspended_at: nil)
    end

    private

    def hasher
      @hasher ||= Veri::Configuration.hasher
    end
  end
end
