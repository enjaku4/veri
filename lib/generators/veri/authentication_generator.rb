require "rails/generators/migration"

module Veri
  class AuthenticationGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path("templates", __dir__)

    argument :table_name, type: :string, required: true

    class_option :uuid, type: :boolean, default: false, desc: "Use UUIDs as primary keys"

    def create_migrations
      # TODO: add original tenant columns
      migration_template "add_veri_authentication.rb.erb", "db/migrate/add_veri_authentication.rb"
    end

    def self.next_migration_number(_path)
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    end
  end
end
