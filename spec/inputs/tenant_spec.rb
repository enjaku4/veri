RSpec.describe Veri::Inputs::Tenant do
  describe "#resolve" do
    subject { described_class.new(tenant, error: Veri::InvalidArgumentError, message: "Error").resolve }

    context "when the given tenant is valid" do
      context "when a string is given" do
        let(:tenant) { "subdomain" }

        it { is_expected.to eq(tenant_type: "subdomain", tenant_id: nil) }
      end

      context "when an instance of ActiveRecord::Base is given" do
        let(:tenant) { Company.create! }

        it { is_expected.to eq(tenant_type: "Company", tenant_id: tenant.id) }
      end

      context "when nil is given" do
        let(:tenant) { nil }

        it { is_expected.to eq(tenant_type: nil, tenant_id: nil) }
      end

      context "when the tenant is already processed" do
        let(:tenant) { { tenant_type: "Company", tenant_id: 1 } }

        it { is_expected.to eq(tenant_type: "Company", tenant_id: 1) }
      end
    end

    context "when the given tenant is invalid" do
      [1, ["tenant"], Company, "", :tenant, {}, :""].each do |invalid_tenant|
        context "when '#{invalid_tenant}' is given" do
          let(:tenant) { invalid_tenant }

          it "raises an error" do
            expect { subject }.to raise_error(Veri::InvalidArgumentError, "Error")
          end
        end
      end

      context "when an instance of ActiveRecord::Base is given but not persisted" do
        let(:tenant) { Company.new }

        it "raises an error" do
          expect { subject }.to raise_error(Veri::InvalidArgumentError, "Error")
        end
      end
    end
  end
end
