RSpec.describe Veri::MigrationHelpers do
  let(:dummy_migration) { Class.new { include Veri::MigrationHelpers }.new }

  before do
    Veri::Session.create!(
      tenant: Client.create!,
      hashed_token: "foo",
      expires_at: 1.hour.ago,
      authenticatable: User.create!,
      last_seen_at: 1.week.ago
    )
    Veri::Session.create!(
      tenant: Client.create!,
      hashed_token: "bar",
      expires_at: 1.hour.ago,
      authenticatable: User.create!,
      last_seen_at: 1.week.ago
    )
    Veri::Session.create!(
      tenant: Company.create!,
      hashed_token: "baz",
      expires_at: 1.hour.ago,
      authenticatable: User.create!,
      last_seen_at: 1.week.ago
    )
  end

  describe "#migrate_authentication_tenant!" do
    it "migrates sessions from old tenant class to new tenant class" do
      sessions = Veri::Session.where(tenant_type: "Client")

      expect(sessions.count).to eq(2)

      dummy_migration.migrate_authentication_tenant!("Client", "Company")

      expect(Veri::Session.where(id: sessions.pluck(:id)).pluck(:tenant_type)).to all(eq("Company"))
    end

    it "does nothing when no sessions exist in the old tenant" do
      expect { dummy_migration.migrate_authentication_tenant!("Organization", "Company") }.not_to(change { Veri::Session.pluck(:tenant_type) })
    end

    context "errors" do
      [nil, "", 1, [1, 2], {}].each do |invalid_tenant|
        it "raises if old tenant class is invalid: #{invalid_tenant.inspect}" do
          expect { dummy_migration.migrate_authentication_tenant!(invalid_tenant, "Company") }.to raise_error(
            Veri::InvalidArgumentError, "Expected a non-empty string, got `#{invalid_tenant.inspect}`"
          )
        end

        it "raises if new tenant class is invalid: #{invalid_tenant.inspect}" do
          expect { dummy_migration.migrate_authentication_tenant!("Client", invalid_tenant) }.to raise_error(
            Veri::InvalidArgumentError, "Expected a non-empty string, got `#{invalid_tenant.inspect}`"
          )
        end
      end
    end
  end

  describe "#delete_authentication_tenant!" do
    it "deletes sessions for the given tenant" do
      sessions = Veri::Session.where(tenant_type: "Company")

      expect(sessions.count).to eq(1)

      dummy_migration.delete_authentication_tenant!("Company")

      expect(Veri::Session.exists?(id: sessions.pluck(:id))).to be false
    end

    it "does nothing when no sessions exist in the tenant" do
      expect { dummy_migration.delete_authentication_tenant!("Organization") }.not_to change(Veri::Session, :count)
    end

    context "errors" do
      [nil, "", 1, [1, 2], {}].each do |invalid_tenant|
        it "raises if tenant class is invalid: #{invalid_tenant.inspect}" do
          expect { dummy_migration.delete_authentication_tenant!(invalid_tenant) }.to raise_error(
            Veri::InvalidArgumentError, "Expected a non-empty string, got `#{invalid_tenant.inspect}`"
          )
        end
      end
    end
  end
end
