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

  describe ".match?" do
    it "matches its own hash format" do
      expect(described_class.match?("sha512$210000$64$c2FsdA==$aGFzaA==")).to be true
    end

    it "does not match other hash formats" do
      expect(described_class.match?("$argon2id$v=19$m=65536,t=2,p=1$c2FsdA$aGFzaA")).to be false
      expect(described_class.match?("$2a$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW")).to be false
      expect(described_class.match?("400$8$1b$deadbeef$cafebabe")).to be false
    end
  end
end
