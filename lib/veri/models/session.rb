require "user_agent_parser"

module Veri
  class Session < ActiveRecord::Base
    self.table_name = "veri_sessions"

    belongs_to :authenticatable, class_name: Veri::Configuration.instance.user_model_name

    def expired?
      expires_at < Time.current
    end

    def inactive?
      inactive_session_lifetime = Veri::Configuration.instance.inactive_session_lifetime

      return false unless inactive_session_lifetime

      last_seen_at < Time.current - inactive_session_lifetime
    end

    alias terminate delete

    def update_info(request)
      processed_request = Veri::Inputs.process(request, as: :request)

      update!(
        last_seen_at: Time.current,
        ip_address: processed_request.remote_ip,
        user_agent: processed_request.user_agent
      )
    end

    def info
      agent = UserAgentParser.parse(user_agent)

      {
        device: agent.device.to_s,
        os: agent.os.to_s,
        browser: agent.to_s,
        ip_address:,
        last_seen_at:
      }
    end

    class << self
      def establish(authenticatable, request)
        token = SecureRandom.hex(32)
        expires_at = Time.current + Veri::Configuration.instance.total_session_lifetime

        new(
          hashed_token: Digest::SHA256.hexdigest(token),
          expires_at:,
          authenticatable: Veri::Inputs.process(authenticatable, as: :authenticatable)
        ).update_info(
          Veri::Inputs.process(request, as: :request)
        )

        token
      end

      def prune_expired(authenticatable = nil)
        processed_authenticatable = Veri::Inputs.process(authenticatable, as: :authenticatable, optional: true)
        scope = processed_authenticatable ? where(authenticatable: processed_authenticatable) : all
        scope.where(expires_at: ...Time.current).delete_all
      end

      def terminate_all(authenticatable)
        Veri::Inputs.process(authenticatable, as: :authenticatable).sessions.delete_all
      end
    end
  end
end
