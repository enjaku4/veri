RSpec.describe Veri::Railtie do
  context "to_prepare initializer" do
    subject { DummyApplication.config.to_prepare_blocks.each(&:call) }

    after do
      Veri::Configuration.reset_to_defaults!
      DummyApplication.config.to_prepare_blocks.each(&:call)
    end

    it "does not query the database" do
      queries = []

      ActiveSupport::Notifications.subscribed(-> (*, payload) { queries << payload[:sql] }, "sql.active_record") { subject }

      expect(queries).to be_empty
    end

    context "when the configured user model does not exist" do
      before { Veri::Configuration.user_model_name = "NonExistentModel" }

      it "does not raise an error" do
        expect { subject }.not_to raise_error
      end
    end

    context "when the configured user model cannot be loaded" do
      before { Veri::Configuration.user_model_name = "BrokenUser" }

      it "does not load it" do
        expect { subject }.not_to raise_error
        expect { BrokenUser }.to raise_error(RuntimeError, "This model cannot be loaded")
      end
    end

    describe "authenticatable associations declaration" do
      before { Veri::Configuration.user_model_name = "Client" }

      it "declares the associations with the user model configured in the initializer" do
        subject
        expect(Veri::Session.reflect_on_association(:authenticatable).klass).to eq(Client)
        expect(Veri::Session.reflect_on_association(:original_authenticatable).klass).to eq(Client)
      end

      it "re-declares the associations on each run without errors or stale classes" do
        expect { 2.times { DummyApplication.config.to_prepare_blocks.each(&:call) } }.not_to raise_error
        expect(Veri::Session.reflect_on_association(:authenticatable).klass).to eq(Client)
        expect(Veri::Session.reflect_on_association(:original_authenticatable).klass).to eq(Client)
      end
    end
  end

  context "include_authenticatable initializer" do
    it "includes Veri::Authenticatable in the configured user model when it is autoloaded" do
      expect(User.ancestors).to include(Veri::Authenticatable)
    end

    it "does not include Veri::Authenticatable in other autoloaded models" do
      expect(Company.ancestors).not_to include(Veri::Authenticatable)
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
