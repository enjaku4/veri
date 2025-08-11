RSpec.describe Veri::Railtie do
  context "to_prepare" do
    subject { DummyApplication.config.to_prepare_blocks.each(&:call) }

    context "when eager_load is true" do
      xit "checks for missing tenant classes"
    end

    context "when eager_load is false" do
      before { allow(Rails.configuration).to receive(:eager_load).and_return(false) }

      xit "checks for missing tenant classes"
    end
  end

  context "extend_migration_helpers" do
    subject { initializer.run(DummyApplication) }

    let(:initializer) { described_class.initializers.detect { |i| i.name == "veri.extend_migration_helpers" } }

    before do
      allow(ActiveSupport).to receive(:on_load).with(:active_record).and_yield
      allow(ActiveRecord::Migration).to receive(:include)
    end

    it "includes Veri::MigrationHelpers in ActiveRecord::Migration" do
      subject
      expect(ActiveRecord::Migration).to have_received(:include).with(Veri::MigrationHelpers)
    end
  end
end
