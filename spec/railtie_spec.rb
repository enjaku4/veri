RSpec.describe Veri::Railtie do
  describe ".server_running?" do
    context "when Rails::Server is defined" do
      before { stub_const("Rails::Server", Class.new) }

      it "returns true" do
        expect(described_class.server_running?).to be true
      end
    end

    context "when Rails::Server is not defined" do
      it "returns false" do
        expect(described_class.server_running?).to be false
      end
    end
  end

  describe ".table_exists?" do
    let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }

    before do
      allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
    end

    context "when veri_sessions table exists" do
      before do
        allow(connection).to receive(:data_source_exists?).with("veri_sessions").and_return(true)
      end

      it "returns true" do
        expect(described_class.table_exists?).to be true
      end
    end

    context "when veri_sessions table does not exist" do
      before do
        allow(connection).to receive(:data_source_exists?).with("veri_sessions").and_return(false)
      end

      it "returns false" do
        expect(described_class.table_exists?).to be false
      end
    end

    context "when database does not exist" do
      before do
        allow(connection).to receive(:data_source_exists?).with("veri_sessions").and_raise(ActiveRecord::NoDatabaseError)
      end

      it "returns false" do
        expect(described_class.table_exists?).to be false
      end
    end

    context "when connection is not established" do
      before do
        allow(connection).to receive(:data_source_exists?).with("veri_sessions").and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it "returns false" do
        expect(described_class.table_exists?).to be false
      end
    end
  end

  context "to_prepare initializer" do
    subject { DummyApplication.config.to_prepare_blocks.each(&:call) }

    before do
      allow(described_class).to receive_messages(server_running?: server_running, table_exists?: table_exists)
    end

    describe "tenant class checking" do
      context "when server is running and table exists" do
        let(:server_running) { true }
        let(:table_exists) { true }

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

      context "when server is not running" do
        let(:server_running) { false }
        let(:table_exists) { true }

        before do
          Veri::Session.create!(
            tenant_type: "NonExistentClass",
            tenant_id: 1,
            hashed_token: "foo",
            expires_at: 1.hour.from_now,
            authenticatable: User.create!,
            last_seen_at: 1.hour.ago
          )
        end

        it "skips tenant class checking and does not raise an error" do
          expect { subject }.not_to raise_error
        end
      end

      context "when table does not exist" do
        let(:server_running) { true }
        let(:table_exists) { false }

        it "skips tenant class checking and does not raise an error" do
          expect { subject }.not_to raise_error
        end
      end
    end

    describe "authenticatable module inclusion" do
      let(:server_running) { true }
      let(:table_exists) { true }
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
