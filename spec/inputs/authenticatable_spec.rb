RSpec.describe Veri::Inputs::Authenticatable do
  shared_examples_for "failed input processing" do |input|
    it "raises an error for invalid input #{input}" do
      expect { described_class.new(input).process }.to raise_error(Veri::InvalidArgumentError)
    end
  end

  describe "valid inputs" do
    it "processes a persisted user" do
      user = User.create!
      expect(described_class.new(user).process).to eq(user)
    end

    it "processes nil as optional" do
      expect(described_class.new(nil, optional: true).process).to be_nil
    end
  end

  describe "invalid inputs" do
    [User.new, Client.new, User, "User", :user, 123, [], {}].each do |invalid_input|
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
