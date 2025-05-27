RSpec.describe Veri::Password::Argon2 do
  describe ".create" do
    let(:hashed_password) { "hashed_password" }

    before { allow(Argon2::Password).to receive(:create).with("secure_password").and_return(hashed_password) }

    it "creates a hashed password" do
      expect(described_class.create("secure_password")).to eq(hashed_password)
    end
  end

  describe ".verify" do
    let(:hashed_password) { described_class.create("secure_password") }

    it "verifies a correct password against a hashed password" do
      expect(described_class.verify("secure_password", hashed_password)).to be true
    end

    it "returns false for an incorrect password" do
      expect(described_class.verify("wrong_password", hashed_password)).to be false
    end
  end
end
