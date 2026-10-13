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

    def update_password(password, terminate_sessions: true)
      hashed_password = hash_password(Veri::Inputs::NonEmptyString.new(password).process)

      transaction do
        sessions.terminate_all if terminate_sessions
        update!(hashed_password:, password_updated_at: Time.current)
      end
    end

    def password_set?
      hashed_password.present?
    end

    def verify_password(password)
      processed_password = Veri::Inputs::NonEmptyString.new(password).process

      return false unless password_set?

      algorithm, hash = hashed_password.split(":", 2)
      stored_hasher = Veri::Configuration::HASHERS[algorithm.to_sym]

      raise Veri::Error, "Unrecognized password hash format" unless stored_hasher

      return false unless stored_hasher.verify(processed_password, hash)

      update_column(:hashed_password, hash_password(processed_password)) unless stored_hasher == Veri::Configuration.hasher

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

    def hash_password(password)
      algorithm = Veri::Configuration.hashing_algorithm

      "#{algorithm}:#{Veri::Configuration::HASHERS.fetch(algorithm).create(password)}"
    end
  end
end
