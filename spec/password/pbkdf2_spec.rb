RSpec.describe Veri::Password::Pbkdf2 do
  describe ".create" do
    let(:salt) { SecureRandom.random_bytes(64) }

    before do
      allow(SecureRandom).to receive(:random_bytes).with(64).and_return(salt)
      allow(OpenSSL::KDF).to receive(:pbkdf2_hmac).with(
        "secure_password", salt:, iterations: 210_000, length: 64, hash: "sha512"
      ).and_return("hashed_password")
    end

    it "creates a hashed password" do
      expect(described_class.create("secure_password")).to eq(
        "sha512$210000$64$#{Base64.strict_encode64(salt)}$#{Base64.strict_encode64("hashed_password")}"
      )
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
