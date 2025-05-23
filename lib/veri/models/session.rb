module Veri
  class Session < ActiveRecord::Base
    self.table_name = "veri_sessions"

    belongs_to :authenticatable, class_name: Veri::Configuration.instance.user_model_name

    def expired? = expires_at < Time.current

    alias terminate delete

    class << self
      def establish(authenticatable)
        token = SecureRandom.hex(32)
        expires_at = Time.current + Veri::Configuration.instance.total_session_lifetime

        create!(hashed_token: Digest::SHA256.hexdigest(token), expires_at:, authenticatable:)

        token
      end

      def prune_expired(authenticatable = nil)
        raise Veri::InvalidArgumentError, "Expects an instance of #{Veri::Configuration.instance.user_model_name} or nil" unless authenticatable.nil? || authenticatable.is_a?(Veri::Configuration.instance.user_model)

        (authenticatable ? where(authenticatable:) : all).where(expires_at: ...Time.current).delete_all
      end

      def terminate_all(authenticatable)
        raise Veri::InvalidArgumentError, "Expects an instance of #{Veri::Configuration.instance.user_model_name}" unless authenticatable.is_a?(Veri::Configuration.instance.user_model)

        authenticatable.sessions.delete_all
      end
    end
  end
end
