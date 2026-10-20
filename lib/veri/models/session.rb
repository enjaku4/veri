require "digest"
require "user_agent_parser"

module Veri
  class Session < ActiveRecord::Base
    self.table_name = "veri_sessions"

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

    def terminate(actor: nil)
      delete.tap do
        Veri::Events.publish("terminate_session") { { session: self, actor: } }
      end
    end

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
    def true_tenant = original_tenant || tenant

    def shapeshift(user, tenant: nil, actor: nil)
      raise Veri::Error, "Cannot shapeshift from a shapeshifted session" if shapeshifted?

      resolved_tenant = Veri::Inputs::Tenant.new(tenant).resolve

      update!(
        shapeshifted_at: Time.current,
        original_authenticatable: authenticatable,
        original_tenant_type: tenant_type,
        original_tenant_id: tenant_id,
        **resolved_tenant,
        authenticatable: Veri::Inputs::Authenticatable.new(user).process
      ).tap do
        Veri::Events.publish("start_impersonation") { { session: self, actor: } }
      end
    end

    def to_true_identity(actor: nil)
      impersonated_identity = authenticatable if Veri::Events.enabled?
      impersonated_tenant = tenant if Veri::Events.enabled?

      update!(
        shapeshifted_at: nil,
        authenticatable: original_authenticatable,
        tenant_type: original_tenant_type,
        tenant_id: original_tenant_id,
        original_tenant_type: nil,
        original_tenant_id: nil,
        original_authenticatable: nil
      ).tap do
        Veri::Events.publish("end_impersonation") { { session: self, actor:, impersonated_identity:, impersonated_tenant: } }
      end
    end

    def switch_tenant(tenant, actor: nil)
      resolved_tenant = Veri::Inputs::Tenant.new(tenant).resolve
      previous_tenant = self.tenant if Veri::Events.enabled?

      update!(**resolved_tenant).tap do
        Veri::Events.publish("switch_tenant") { { session: self, actor:, previous_tenant: } }
      end
    end

    def tenant
      resolve_tenant(tenant_type, tenant_id) { super }
    end

    def original_tenant
      resolve_tenant(original_tenant_type, original_tenant_id) { super }
    end

    class << self
      def establish(user, request, resolved_tenant, actor: nil)
        token = SecureRandom.hex(32)
        expires_at = Time.current + Veri::Configuration.total_session_lifetime

        session = new(
          hashed_token: digest_token(token),
          expires_at:,
          authenticatable: user,
          **resolved_tenant
        )
        session.update_info(request)

        Veri::Events.publish("establish_session") { { session:, actor: } }

        token
      end

      def prune
        orphaned_tenant_sessions = where.not(tenant_id: nil).includes(:tenant).filter_map do |session|
          !session.tenant
        rescue ActiveRecord::RecordNotFound
          session.id
        end

        where(id: orphaned_tenant_sessions).delete_all if orphaned_tenant_sessions.any?
      end

      def terminate_all(actor: nil)
        return delete_all unless Veri::Events.enabled?

        transaction do
          in_batches.sum do |batch|
            sessions = batch.to_a

            batch.delete_all
            sessions.each { |session| Veri::Events.publish("terminate_session") { { session:, actor: } } }
            sessions.size
          end
        end
      end

      def from_request(request)
        token = request.cookie_jar.encrypted["veri_token"]

        return nil if token.blank?

        session = find_by(hashed_token: digest_token(token))

        session&.active? ? session : nil
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
