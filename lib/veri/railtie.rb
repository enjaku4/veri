require "rails/railtie"

module Veri
  class Railtie < Rails::Railtie
    initializer "veri.to_prepare" do |app|
      app.config.to_prepare do
        connection = ActiveRecord::Base.connection
        if connection.database_exists? && connection.data_source_exists?("veri_sessions")
          Veri::Session.where.not(tenant_id: nil).distinct.pluck(:tenant_type).each do |tenant_class|
            tenant_class.constantize
          rescue NameError => e
            raise Veri::Error, "Tenant not found: class `#{e.name}` may have been renamed or deleted"
          end
        end

        user_model = Veri::Configuration.user_model
        user_model.include Veri::Authenticatable unless user_model < Veri::Authenticatable
      end
    end

    initializer "veri.extend_migration_helpers" do
      ActiveSupport.on_load :active_record do
        ActiveRecord::Migration.include Veri::MigrationHelpers
      end
    end
  end
end
