RSpec.describe Veri::Railtie do
  context "to_prepare" do
    subject { DummyApplication.config.to_prepare_blocks.each(&:call) }

    describe "tenant class checking" do
      before do
        Veri::Session.create!(
          tenant_type:,
          tenant_id:,
          hashed_token: "foo",
          expires_at: 1.hour.from_now,
          authenticatable: User.create!,
          last_seen_at: 1.hour.ago
        )
      end

      context "when all tenants exist" do
        let(:tenant_type) { "Company" }
        let(:tenant_id) { 1 }

        it "does not raise an error" do
          expect { subject }.not_to raise_error
        end
      end

      context "when a tenant class does not exist" do
        let(:tenant_type) { "NonExistentClass" }
        let(:tenant_id) { 1 }

        it "raises a Veri::Error" do
          expect { subject }.to raise_error(
            Veri::Error, "Tenant not found: class `NonExistentClass` may have been renamed or deleted"
          )
        end
      end
    end

    describe "authenticatable module inclusion" do
      let(:user_model) { class_double(User) }

      before { allow(Veri::Configuration).to receive(:user_model).and_return(user_model) }

      context "when user model already includes Veri::Authenticatable" do
        before { allow(user_model).to receive(:<).with(Veri::Authenticatable).and_return(true) }

        it "does not include Veri::Authenticatable again" do
          expect(user_model).not_to receive(:include).with(Veri::Authenticatable)
          subject
        end
      end

      context "when user model does not include Veri::Authenticatable" do
        before { allow(user_model).to receive(:<).with(Veri::Authenticatable).and_return(false) }

        it "includes Veri::Authenticatable in the user model" do
          expect(user_model).to receive(:include).with(Veri::Authenticatable)
          subject
        end
      end
    end
  end

  context "extend_migration_helpers" do
    subject { initializer.run(DummyApplication) }

    let(:initializer) { described_class.initializers.detect { |i| i.name == "veri.extend_migration_helpers" } }

    before do
      allow(ActiveSupport).to receive(:on_load).with(:active_record).and_yield
      allow(ActiveRecord::Migration).to receive(:include).with(Veri::MigrationHelpers)
    end

    it "includes Veri::MigrationHelpers in ActiveRecord::Migration" do
      subject
      expect(ActiveRecord::Migration).to have_received(:include)
    end
  end
end
