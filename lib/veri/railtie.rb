require "rails/railtie"

module Veri
  class Railtie < Rails::Railtie
    initializer "veri.include_authenticatable" do
      Rails.autoloaders.main.on_load do |cpath, klass, _abspath|
        klass.include Veri::Authenticatable if cpath == Veri::Configuration.user_model_name
      end
    end

    initializer "veri.to_prepare" do |app|
      app.config.to_prepare do
        Veri::Session.belongs_to :authenticatable, class_name: Veri::Configuration.user_model_name
        Veri::Session.belongs_to :original_authenticatable, class_name: Veri::Configuration.user_model_name, optional: true
      end
    end

    initializer "veri.extend_migration_helpers" do
      ActiveSupport.on_load :active_record do
        ActiveRecord::Migration.include Veri::MigrationHelpers
      end
    end
  end
end
