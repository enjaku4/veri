require "rails/engine"

module Veri
  class Engine < Rails::Engine
    initializer "veri.include_authenticatable" do
      Rails.autoloaders.each do |autoloader|
        autoloader.on_load do |cpath, klass, _abspath|
          klass.include Veri::Authenticatable if cpath == Veri::Configuration.user_model_name
        end
      end
    end

    initializer "veri.extend_migration_helpers" do
      ActiveSupport.on_load :active_record do
        ActiveRecord::Migration.include Veri::MigrationHelpers
      end
    end
  end
end
