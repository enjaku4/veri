require "digest"
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
    def true_tenant = shapeshifted? ? original_tenant : tenant

    def shapeshift(user, tenant: nil)
      raise Veri::Error, "Cannot shapeshift from a shapeshifted session" if shapeshifted?

      processed_authenticatable = Veri::Inputs::Authenticatable.new(user).process
      resolved_tenant = Veri::Inputs::Tenant.new(tenant).resolve

      processed_authenticatable.transaction do
        locked_authenticatable = processed_authenticatable.class.unscoped.lock.find(processed_authenticatable.id)

        raise Veri::Error, "Cannot shapeshift into a suspended user" if locked_authenticatable.suspended?

        update!(
          shapeshifted_at: Time.current,
          original_authenticatable: authenticatable,
          original_tenant_type: tenant_type,
          original_tenant_id: tenant_id,
          **resolved_tenant,
          authenticatable: processed_authenticatable
        )
      end
    end

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

    def switch_tenant(tenant)
      update!(**Veri::Inputs::Tenant.new(tenant).resolve)
    end

    def tenant
      resolve_tenant(tenant_type, tenant_id) { super }
    end

    def original_tenant
      resolve_tenant(original_tenant_type, original_tenant_id) { super }
    end

    class << self
      def establish(user, request, resolved_tenant)
        token = SecureRandom.hex(32)
        expires_at = Time.current + Veri::Configuration.total_session_lifetime

        session = new(
          hashed_token: digest_token(token),
          expires_at:,
          authenticatable: user,
          **resolved_tenant
        )
        session.update_info(request)

        token
      end

      def prune
        orphaned_sessions = where.not(tenant_id: nil).or(where.not(original_tenant_id: nil)).includes(:tenant, :original_tenant).select do |session|
          session.tenant
          session.original_tenant
          false
        rescue ActiveRecord::RecordNotFound
          true
        end

        where(id: orphaned_sessions).delete_all if orphaned_sessions.any?
      end

      alias terminate_all delete_all

      def from_request(request)
        token = Veri::Inputs::Request.new(request).process.cookie_jar.encrypted["veri_token"]

        return nil if token.blank?

        session = find_by(hashed_token: digest_token(token))

        return nil unless session&.active?

        raise Veri::Error, "Session belongs to a suspended user" if session.identity.suspended? || session.true_identity.suspended?

        session
      end

      private

      def digest_token(token)
        Digest::SHA256.hexdigest(token)
      end
    end

    private

    def resolve_tenant(type, id)
      return type if type.present? && id.blank?

      record = yield

      raise ActiveRecord::RecordNotFound.new(nil, type, nil, id) if id.present? && !record

      record
    end
  end
end
