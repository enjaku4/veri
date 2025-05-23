require "user_agent_parser"

module Veri
  class Session < ActiveRecord::Base
    self.table_name = "veri_sessions"

    belongs_to :authenticatable, class_name: Veri::Configuration.instance.user_model_name

    def expired? = expires_at < Time.current

    alias terminate delete

    def update_info(request)
      raise Veri::InvalidArgumentError, "Expects an instance of ActionDispatch::Request" unless request.is_a?(ActionDispatch::Request)

      update!(
        last_seen_at: Time.current,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end

    def info
      user_agent = UserAgentParser.parse(last_user_agent)

      {
        device: user_agent.device.to_s,
        os: user_agent.os.to_s,
        browser: user_agent.to_s,
        ip_address:,
        last_seen_at:
      }
    end

    class << self
      def establish(authenticatable)
        raise Veri::InvalidArgumentError, "Expects an instance of #{Veri::Configuration.instance.user_model_name}" unless authenticatable.is_a?(Veri::Configuration.instance.user_model)

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
