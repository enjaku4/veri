module Veri
  module MigrationHelpers
    def migrate_authentication_tenant!(old_tenant, new_tenant)
      old_tenant_type = Veri::Inputs::NonEmptyString.new(old_tenant).process
      new_tenant_type = Veri::Inputs::NonEmptyString.new(new_tenant).process

      Veri::Session.transaction do
        Veri::Session.where(tenant_type: old_tenant_type).update_all(tenant_type: new_tenant_type)
        Veri::Session.where(original_tenant_type: old_tenant_type).update_all(original_tenant_type: new_tenant_type)
      end
    end

    def delete_authentication_tenant!(tenant)
      tenant_type = Veri::Inputs::NonEmptyString.new(tenant).process

      Veri::Session.where(tenant_type:).or(Veri::Session.where(original_tenant_type: tenant_type)).delete_all
    end
  end
end
