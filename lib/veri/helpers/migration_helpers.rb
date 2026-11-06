module Veri
  module MigrationHelpers
    def migrate_authentication_tenant!(old_tenant, new_tenant)
      old_tenant_type = Veri::Inputs::NonEmptyString.new(old_tenant).process
      new_tenant_type = Veri::Inputs::NonEmptyString.new(new_tenant).process

      Veri::Session.where(tenant_type: old_tenant_type).update_all(tenant_type: new_tenant_type)
    end

    def delete_authentication_tenant!(tenant)
      Veri::Session.where(tenant_type: Veri::Inputs::NonEmptyString.new(tenant).process).delete_all
    end
  end
end
