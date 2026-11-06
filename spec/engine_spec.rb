RSpec.describe Veri::Engine do
  context "include_authenticatable initializer" do
    it "includes Veri::Authenticatable in the configured user model when it is autoloaded" do
      expect(User.ancestors).to include(Veri::Authenticatable)
    end

    it "does not include Veri::Authenticatable in other autoloaded models" do
      expect(Company.ancestors).not_to include(Veri::Authenticatable)
    end

    it "registers the hook with every Rails autoloader" do
      Rails.autoloaders.each { allow(_1).to receive(:on_load) }

      described_class.initializers.detect { _1.name == "veri.include_authenticatable" }.run(DummyApplication)

      expect(Rails.autoloaders.to_a).to all(have_received(:on_load))
    end
  end

  context "extend_migration_helpers initializer" do
    subject { initializer.run(DummyApplication) }

    let(:initializer) { described_class.initializers.detect { |i| i.name == "veri.extend_migration_helpers" } }

    before do
      allow(ActiveSupport).to receive(:on_load).with(:active_record).and_yield
      allow(ActiveRecord::Migration).to receive(:include).with(Veri::MigrationHelpers)
    end

    it "includes Veri::MigrationHelpers in ActiveRecord::Migration" do
      subject
      expect(ActiveRecord::Migration).to have_received(:include).with(Veri::MigrationHelpers)
    end
  end
end
