RSpec.describe Veri::Inputs::Model do
  shared_examples_for "successful input processing" do |input, output = input|
    it "processes #{input}" do
      expect(described_class.new(input).process).to eq(output)
    end

    it "processes #{input} as optional" do
      expect(described_class.new(nil, optional: true).process).to be_nil
    end
  end

  shared_examples_for "failed input processing" do |input|
    it "raises an error for invalid input #{input}" do
      expect { described_class.new(input).process }.to raise_error(Veri::InvalidArgumentError)
    end
  end

  describe "valid inputs" do
    { "User" => User, "Client" => Client }.each do |model_name, model|
      it_behaves_like "successful input processing", model_name, model
    end
  end

  describe "invalid inputs" do
    ["NonExistentModel", "Veri", Veri, 123, [], {}, :foo].each do |invalid_input|
      it_behaves_like "failed input processing", invalid_input
    end
  end

  describe "custom error handling" do
    it "raises custom error class when specified" do
      expect { described_class.new("invalid", error: ArgumentError).process }.to raise_error(ArgumentError)
    end

    it "raises custom error message when specified" do
      expect { described_class.new("invalid", message: "Custom message").process }.to raise_error(Veri::InvalidArgumentError, "Custom message")
    end
  end
end
