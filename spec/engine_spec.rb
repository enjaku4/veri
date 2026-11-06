RSpec.describe Veri::Engine do
  describe "user model" do
    it "includes Veri::Authenticatable in the configured user model when it is autoloaded" do
      expect(User.ancestors).to include(Veri::Authenticatable)
    end

    it "does not include Veri::Authenticatable in other autoloaded models" do
      expect(Company.ancestors).not_to include(Veri::Authenticatable)
    end
  end

  describe "migrations" do
    it "can use the migration helpers" do
      expect(ActiveRecord::Migration.new).to respond_to(:migrate_authentication_tenant!, :delete_authentication_tenant!)
    end
  end
end
