require "user_agent_parser"

module Veri
  class Session < ActiveRecord::Base
    self.table_name = "veri_sessions"

    belongs_to :authenticatable, class_name: Veri::Configuration.user_model_name
    belongs_to :original_authenticatable, class_name: Veri::Configuration.user_model_name, optional: true
    belongs_to :tenant, polymorphic: true, optional: true
    belongs_to :original_tenant, polymorphic: true, optional: true

    scope :in_tenant, -> (tenant) { where(**Veri::Inputs::Tenant.new(tenant).resolve) }
    scope :active, -> { where.not(id: expired.select(:id)).where.not(id: inactive.select(:id)) }
    scope :expired, -> { where(expires_at: ...Time.current) }
    scope :inactive, -> do
      inactive_session_lifetime = Veri::Configuration.inactive_session_lifetime
      inactive_session_lifetime ? where(last_seen_at: ...(Time.current - inactive_session_lifetime)) : none
    end

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

    # TODO: add specs
    def shapeshift(user, tenant: nil)
      resolved_tenant ||= Veri::Inputs::Tenant.new(
        tenant,
        error: Veri::InvalidTenantError,
        message: "Expected a string, an ActiveRecord model instance, or nil, got `#{tenant.inspect}`"
      ).resolve

      update!(
        shapeshifted_at: Time.current,
        original_authenticatable: authenticatable,
        original_tenant_type: tenant_type,
        original_tenant_id: tenant_id,
        **resolved_tenant,
        authenticatable: Veri::Inputs::Authenticatable.new(
          user,
          message: "Expected an instance of #{Veri::Configuration.user_model_name}, got `#{user.inspect}`"
        ).process
      )
    end

    # TODO: add specs
    def to_true_identity
      update!(
        shapeshifted_at: nil,
        authenticatable: original_authenticatable,
        tenant_type: original_tenant_type,
        tenant_id: original_tenant_id,
        original_tenant_type: nil,
        original_tenant_id: nil,
        original_authenticatable: nil
      )
    end

    def tenant
      return tenant_type if tenant_type.present? && tenant_id.blank?

      record = super

      raise ActiveRecord::RecordNotFound.new(nil, tenant_type, nil, tenant_id) if tenant_id.present? && !record

      record
    end

    # TODO: sort out duplicated code, add specs
    def original_tenant
      return original_tenant_type if original_tenant_type.present? && original_tenant_id.blank?

      record = super

      raise ActiveRecord::RecordNotFound.new(nil, original_tenant_type, nil, original_tenant_id) if original_tenant_id.present? && !record

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

      def prune
        expired.or(inactive).delete_all

        orphaned_tenant_sessions = where.not(tenant_id: nil).includes(:tenant).filter_map do |session|
          !session.tenant
        rescue ActiveRecord::RecordNotFound
          session.id
        end

        where(id: orphaned_tenant_sessions).delete_all if orphaned_tenant_sessions.any?
      end

      alias terminate_all delete_all
    end
  end
end
