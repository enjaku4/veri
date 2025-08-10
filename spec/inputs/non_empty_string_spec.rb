RSpec.describe Veri::Inputs::NonEmptyString do
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
    ["valid string", " "].each do |string|
      it_behaves_like "successful input processing", string
    end
  end

  describe "invalid inputs" do
    [nil, [], {}, :foo, 123, Veri, ""].each do |invalid_input|
      it_behaves_like "failed input processing", invalid_input
    end
  end

  describe "custom error handling" do
    it "raises custom error class when specified" do
      expect { described_class.new("", error: ArgumentError).process }.to raise_error(ArgumentError)
    end

    it "raises custom error message when specified" do
      expect { described_class.new("", message: "Custom message").process }.to raise_error(Veri::InvalidArgumentError, "Custom message")
    end
  end
end
