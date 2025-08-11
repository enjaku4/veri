module Veri
  module MigrationHelpers
    def migrate_authentication_tenant!(old_tenant, new_tenant)
      sessions = Veri::Session.where(tenant_type: old_tenant.to_s)

      raise Veri::InvalidArgumentError, "No sessions exist in tenant #{old_tenant.inspect}" unless sessions.exists?
      raise Veri::InvalidArgumentError, "Cannot migrate tenant to #{new_tenant.inspect}: class does not exist" unless new_tenant.to_s.safe_constantize

      sessions.update_all(tenant_type: new_tenant.to_s)
    end

    def delete_authentication_tenant!(tenant)
      sessions = Veri::Session.where(tenant_type: tenant.to_s)

      raise Veri::InvalidArgumentError, "No sessions exist in tenant #{tenant.inspect}" unless sessions.exists?

      sessions.delete_all
    end
  end
end
