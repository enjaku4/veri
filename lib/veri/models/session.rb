require "user_agent_parser"

module Veri
  class Session < ActiveRecord::Base
    self.table_name = "veri_sessions"

    belongs_to :authenticatable, class_name: Veri::Configuration.user_model_name # rubocop:disable Rails/ReflectionClassName

    def active?
      !expired? && !inactive?
    end

    def expired?
      expires_at < Time.current
    end

    def inactive?
      inactive_session_lifetime = Veri::Configuration.inactive_session_lifetime

      return false unless inactive_session_lifetime

      last_seen_at < Time.current - inactive_session_lifetime
    end

    alias terminate delete

    def update_info(request)
      processed_request = Veri::Inputs.process(request, as: :request, error: Veri::Error)

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

    def shapeshifted?
      # TODO
    end

    def original_identity
      # TODO
    end

    def identity
      # TODO
    end

    class << self
      def establish(authenticatable, request)
        token = SecureRandom.hex(32)
        expires_at = Time.current + Veri::Configuration.total_session_lifetime

        new(
          hashed_token: Digest::SHA256.hexdigest(token),
          expires_at:,
          authenticatable: Veri::Inputs.process(authenticatable, as: :authenticatable, error: Veri::Error)
        ).update_info(
          Veri::Inputs.process(request, as: :request, error: Veri::Error)
        )

        token
      end

      def prune(authenticatable = nil)
        processed_authenticatable = Veri::Inputs.process(authenticatable, as: :authenticatable, optional: true)
        scope = processed_authenticatable ? where(authenticatable: processed_authenticatable) : all
        to_be_pruned = scope.where(expires_at: ...Time.current)
        if Veri::Configuration.inactive_session_lifetime
          to_be_pruned = to_be_pruned.or(
            scope.where(last_seen_at: ...(Time.current - Veri::Configuration.inactive_session_lifetime))
          )
        end
        to_be_pruned.delete_all
      end

      def terminate_all(authenticatable)
        Veri::Inputs.process(authenticatable, as: :authenticatable).veri_sessions.delete_all
      end
    end
  end
end
