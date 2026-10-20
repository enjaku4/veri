RSpec.describe Veri::Events do
  describe ".publish" do
    let(:payload) { { value: "example" } }

    before { allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original }

    context "when events are disabled" do
      it "publishes nothing and does not build the payload" do
        expect(ActiveSupport::Notifications).not_to receive(:instrument).with("example.veri", anything)

        described_class.publish("example") { raise "payload should not be built" }
      end
    end

    context "when events are enabled" do
      before { Veri::Configuration.configure { _1.events_enabled = true } }

      it "publishes the namespaced event and payload immediately outside a transaction" do
        described_class.publish("example") { payload }

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("example.veri", payload)
      end

      it "builds the payload immediately but publishes only after commit" do
        payload_built = false

        ActiveRecord::Base.transaction do
          described_class.publish("example") do
            payload_built = true
            payload
          end

          expect(payload_built).to be true
          expect(ActiveSupport::Notifications).not_to have_received(:instrument).with("example.veri", anything)
        end

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("example.veri", payload)
      end

      it "publishes nothing when the transaction is rolled back" do
        expect(ActiveSupport::Notifications).not_to receive(:instrument).with("example.veri", anything)

        ActiveRecord::Base.transaction do
          described_class.publish("example") { payload }
          raise ActiveRecord::Rollback
        end
      end
    end
  end
end
