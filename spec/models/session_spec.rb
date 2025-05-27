RSpec.describe Veri::Session do
  describe "#expired?" do
    subject { described_class.new(expires_at: expires_at).expired? }

    context "when expires_at is in the past" do
      let(:expires_at) { 1.minute.ago }

      it { is_expected.to be true }
    end

    context "when expires_at is in the future" do
      let(:expires_at) { 1.minute.from_now }

      it { is_expected.to be false }
    end
  end

  describe "#inactive?" do
    subject { described_class.new(last_seen_at: 5.minutes.ago).inactive? }

    context "when inactive session lifetime is set" do
      context "and last_seen_at is older than inactive session lifetime" do
        before { Veri::Configuration.configure { _1.inactive_session_lifetime = 4.minutes } }

        it { is_expected.to be true }
      end

      context "and last_seen_at is within inactive session lifetime" do
        before { Veri::Configuration.configure { _1.inactive_session_lifetime = 6.minutes } }

        it { is_expected.to be false }
      end
    end

    context "when inactive session lifetime is not set" do
      before { Veri::Configuration.configure { _1.inactive_session_lifetime = nil } }

      it { is_expected.to be false }
    end
  end

  describe "#terminate" do
    let!(:session) do
      described_class.create!(
        expires_at: 1.hour.from_now,
        authenticatable: User.create!,
        hashed_token: "foo",
        last_seen_at: Time.current
      )
    end

    it "deletes the session" do
      expect { session.terminate }.to change(described_class, :count).from(1).to(0)
      expect(session).to be_destroyed
    end
  end

  describe "#update_info" do
    subject { session.update_info(request) }

    let(:session) { described_class.new(hashed_token: "foo", expires_at: 1.hour.from_now, authenticatable: User.new) }

    context "when request is valid" do
      let(:request) { ActionDispatch::Request.new("REMOTE_ADDR" => "1.2.3.4", "HTTP_USER_AGENT" => "IE7") }

      it "updates last_seen_at, ip_address, and user_agent and persists the session" do
        expect { session.update_info(request) }
          .to change(session, :last_seen_at).from(nil).to(be_within(3.seconds).of(Time.current))
          .and change(session, :ip_address).from(nil).to("1.2.3.4")
          .and change(session, :user_agent).from(nil).to("IE7")
          .and change(session, :persisted?).from(false).to(true)
      end
    end

    context "when request is invalid" do
      let(:request) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::Error)
      end
    end
  end

  describe "#info" do
    let(:last_seen_at) { 5.minutes.ago }
    let(:session) do
      described_class.new(
        ip_address: "1.2.3.4",
        last_seen_at:,
        user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
        authenticatable: User.new,
        hashed_token: "foo",
        expires_at: 1.hour.from_now
      )
    end

    it "returns a hash with device, os, browser, ip_address, and last_seen_at" do
      expect(session.info).to eq(
        {
          device: "Other",
          os: "Windows 10",
          browser: "Chrome 58.0.3029.110",
          ip_address: "1.2.3.4",
          last_seen_at:
        }
      )
    end
  end

  describe ".establish" do
    subject { described_class.establish(authenticatable, request) }

    context "when authenticatable is invalid" do
      let(:authenticatable) { nil }
      let(:request) { ActionDispatch::Request.new("REMOTE_ADDR" => "1.2.3.4") }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::Error)
      end
    end

    context "when request is invalid" do
      let(:authenticatable) { User.create! }
      let(:request) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::Error)
      end
    end

    context "when both authenticatable and request are valid" do
      let(:authenticatable) { User.create! }
      let(:request) { ActionDispatch::Request.new("REMOTE_ADDR" => "1.2.3.4", "HTTP_USER_AGENT" => "IE7") }

      before do
        allow(SecureRandom).to receive(:hex).with(32).and_return("token")
        allow(Digest::SHA256).to receive(:hexdigest).with("token").and_return("hashed_token")
        Veri::Configuration.configure { _1.total_session_lifetime = 1.hour }
      end

      it "creates a new session and returns the token" do
        expect { subject }.to change(described_class, :count).from(0).to(1)
        expect(subject).to eq("token")
        expect(described_class.last).to have_attributes(
          hashed_token: "hashed_token",
          expires_at: be_within(3.seconds).of(1.hour.from_now),
          authenticatable:,
          ip_address: "1.2.3.4",
          user_agent: "IE7",
          last_seen_at: be_within(3.seconds).of(Time.current)
        ).and be_persisted
      end
    end
  end

  describe ".prune_expired" do
    subject { described_class.prune_expired(authenticatable) }

    context "when authenticatable is invalid" do
      let(:authenticatable) { Client.create! }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::InvalidArgumentError)
      end
    end

    context "when authenticatable is nil" do
      let(:authenticatable) { nil }
      let!(:session) do
        described_class.create!(
          expires_at: 1.hour.from_now,
          authenticatable: User.create!,
          hashed_token: "foo",
          last_seen_at: Time.current
        )
      end

      before do
        Array.new(3) do |i|
          described_class.create!(
            expires_at: 1.hour.ago,
            authenticatable: User.create!,
            hashed_token: "foo#{i}",
            last_seen_at: Time.current
          )
        end
      end

      it "deletes all expired sessions" do
        expect { subject }.to change(described_class, :count).from(4).to(1)
        expect(described_class.where(id: session.id)).to all(be_persisted)
      end
    end

    context "when authenticatable is present" do
      let(:authenticatable) { User.create! }
      let!(:sessions) do
        Array.new(3) do |i|
          described_class.create!(
            expires_at: 1.hour.ago,
            authenticatable:,
            hashed_token: "foo#{i}",
            last_seen_at: Time.current
          )
        end
      end

      before do
        Array.new(3) do |i|
          described_class.create!(
            expires_at: 1.hour.ago,
            authenticatable: User.create!,
            hashed_token: "bar#{i}",
            last_seen_at: Time.current
          )
        end
        described_class.create!(
          expires_at: 1.hour.from_now,
          authenticatable:,
          hashed_token: "baz",
          last_seen_at: Time.current
        )
      end

      it "deletes only expired sessions for the given authenticatable" do
        expect { subject }.to change(described_class, :count).from(7).to(4)
        expect(described_class.where(id: sessions)).to all(be_destroyed)
      end
    end
  end

  describe ".terminate_all" do
    subject { described_class.terminate_all(authenticatable) }

    context "when authenticatable is invalid" do
      let(:authenticatable) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::InvalidArgumentError)
      end
    end

    context "when authenticatable is valid" do
      let(:authenticatable) { User.create! }
      let!(:sessions) do
        Array.new(3) do |i|
          described_class.create!(
            expires_at: 1.hour.from_now,
            authenticatable:,
            hashed_token: "foo#{i}",
            last_seen_at: Time.current
          )
        end
      end

      it "deletes all sessions for the given authenticatable" do
        expect { subject }.to change(described_class, :count).from(3).to(0)
        expect(described_class.where(id: sessions)).to all(be_destroyed)
      end
    end
  end
end
