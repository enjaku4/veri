require "user_agent_parser"

module Veri
  class Session < ActiveRecord::Base
    self.table_name = "veri_sessions"

    # rubocop:disable Rails/ReflectionClassName
    belongs_to :authenticatable, class_name: Veri::Configuration.user_model_name
    belongs_to :original_authenticatable, class_name: Veri::Configuration.user_model_name, optional: true
    belongs_to :tenant, polymorphic: true, optional: true
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
      update!(
        last_seen_at: Time.current,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
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
        authenticatable: Veri::Inputs::Authenticatable.new(
          user,
          message: "Expected an instance of #{Veri::Configuration.user_model_name}, got `#{user.inspect}`"
        ).process
      )
    end

    def revert_to_true_identity
      update!(
        shapeshifted_at: nil,
        authenticatable: original_authenticatable,
        original_authenticatable: nil
      )
    end

    def tenant
      return tenant_type if tenant_type.present? && tenant_id.blank?

      record = super

      raise ActiveRecord::RecordNotFound.new(nil, tenant_type, nil, tenant_id) if tenant_id.present? && !record

      record
    end

    class << self
      def establish(user, request, resolved_tenant)
        token = SecureRandom.hex(32)
        expires_at = Time.current + Veri::Configuration.total_session_lifetime

        new(
          hashed_token: Digest::SHA256.hexdigest(token),
          expires_at:,
          authenticatable: user,
          **resolved_tenant
        ).update_info(request)

        token
      end

      # TODO: probably needs prune_inactive, and prune_missing_tenants methods
      # TODO: also probably needs migration helpers for tenant name update and delete
      # TODO: also fail fast automatically if tenant class doesn't exist
      def prune(user = nil)
        scope = if user
                  where(
                    authenticatable: Veri::Inputs::Authenticatable.new(
                      user,
                      optional: true,
                      message: "Expected an instance of #{Veri::Configuration.user_model_name} or nil, got `#{user.inspect}`"
                    ).process
                  )
                else
                  all
                end

        expired_scope = scope.where(expires_at: ...Time.current)

        if Veri::Configuration.inactive_session_lifetime
          inactive_cutoff = Time.current - Veri::Configuration.inactive_session_lifetime
          expired_scope = expired_scope.or(scope.where(last_seen_at: ...inactive_cutoff))
        end

        expired_scope.delete_all
      end

      def terminate_all(user)
        Veri::Inputs::Authenticatable.new(
          user,
          message: "Expected an instance of #{Veri::Configuration.user_model_name}, got `#{user.inspect}`"
        ).process.veri_sessions.delete_all
      end
    end
  end
end
