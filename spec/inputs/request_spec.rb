RSpec.describe Veri::Inputs::Request do
  describe "valid inputs" do
    it "processes a request" do
      request = ActionDispatch::TestRequest.create
      expect(described_class.new(request).process).to eq(request)
    end
  end

  describe "invalid inputs" do
    [nil, "request", Rack::Request.new({}), 123, [], {}].each do |invalid_input|
      it "raises an error for invalid input #{invalid_input.inspect}" do
        expect { described_class.new(invalid_input).process }.to raise_error(Veri::InvalidArgumentError)
      end
    end
  end
end
