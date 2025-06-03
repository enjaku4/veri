require "user_agent_parser"

module Veri
  class Session < ActiveRecord::Base
    self.table_name = "veri_sessions"

    # rubocop:disable Rails/ReflectionClassName
    belongs_to :authenticatable, class_name: Veri::Configuration.user_model_name
    belongs_to :original_authenticatable, class_name: Veri::Configuration.user_model_name, optional: true
    # rubocop:enable Rails/ReflectionClassName

    def active? = !expired? && !inactive?

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

    def identity = authenticatable
    def shapeshifted? = original_authenticatable.present?
    def true_identity = original_authenticatable || authenticatable

    def shapeshift(user)
      update!(
        shapeshifted_at: Time.current,
        original_authenticatable: authenticatable,
        authenticatable: Veri::Inputs.process(user, as: :authenticatable)
      )
    end

    def revert_to_true_identity
      update!(
        shapeshifted_at: nil,
        authenticatable: original_authenticatable,
        original_authenticatable: nil
      )
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
