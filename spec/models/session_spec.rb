RSpec.describe Veri::Session do
  describe ".active" do
    subject { described_class.active }

    let!(:active_session) do
      described_class.create!(
        expires_at: 1.hour.from_now,
        authenticatable: User.create!,
        hashed_token: "foo",
        last_seen_at: Time.current
      )
    end

    before do
      Veri::Configuration.configure { _1.inactive_session_lifetime = 5.minutes }
      described_class.create!(
        expires_at: 1.hour.ago,
        authenticatable: User.create!,
        hashed_token: "bar",
        last_seen_at: Time.current
      )
      described_class.create!(
        expires_at: 1.hour.from_now,
        authenticatable: User.create!,
        hashed_token: "baz",
        last_seen_at: 10.minutes.ago
      )
    end

    it { is_expected.to contain_exactly(active_session) }
  end

  describe ".expired" do
    subject { described_class.expired }

    let!(:expired_session) do
      described_class.create!(
        expires_at: 1.hour.ago,
        authenticatable: User.create!,
        hashed_token: "foo",
        last_seen_at: Time.current
      )
    end

    before do
      described_class.create!(
        expires_at: 1.hour.from_now,
        authenticatable: User.create!,
        hashed_token: "bar",
        last_seen_at: Time.current
      )
    end

    it { is_expected.to contain_exactly(expired_session) }
  end

  describe ".inactive" do
    subject { described_class.inactive }

    let!(:inactive_session) do
      described_class.create!(
        expires_at: 1.hour.from_now,
        authenticatable: User.create!,
        hashed_token: "foo",
        last_seen_at: 10.minutes.ago
      )
    end

    before do
      Veri::Configuration.configure { _1.inactive_session_lifetime = 5.minutes }
      described_class.create!(
        expires_at: 1.hour.from_now,
        authenticatable: User.create!,
        hashed_token: "bar",
        last_seen_at: Time.current
      )
    end

    it { is_expected.to contain_exactly(inactive_session) }
  end

  describe "active?" do
    subject { described_class.new(expires_at:, last_seen_at:).active? }

    context "when session is active" do
      let(:expires_at) { 1.hour.from_now }
      let(:last_seen_at) { Time.current }

      it { is_expected.to be true }
    end

    context "when session is expired" do
      let(:expires_at) { 1.minute.ago }
      let(:last_seen_at) { Time.current }

      it { is_expected.to be false }
    end

    context "when session is inactive" do
      let(:expires_at) { 1.hour.from_now }
      let(:last_seen_at) { 5.minutes.ago }

      before { Veri::Configuration.configure { _1.inactive_session_lifetime = 4.minutes } }

      it { is_expected.to be false }
    end
  end

  describe "#expired?" do
    subject { described_class.new(expires_at:).expired? }

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
    let(:request) { ActionDispatch::Request.new("REMOTE_ADDR" => "1.2.3.4", "HTTP_USER_AGENT" => "IE7") }

    it "updates last_seen_at, ip_address, and user_agent and persists the session" do
      expect { session.update_info(request) }
        .to change(session, :last_seen_at).from(nil).to(be_within(3.seconds).of(Time.current))
        .and change(session, :ip_address).from(nil).to("1.2.3.4")
        .and change(session, :user_agent).from(nil).to("IE7")
        .and change(session, :persisted?).from(false).to(true)
    end
  end

  describe "#info" do
    let(:session) do
      described_class.new(
        ip_address: "1.2.3.4",
        last_seen_at: Time.current,
        user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
        authenticatable: User.new,
        hashed_token: "foo",
        expires_at: 1.hour.from_now
      )
    end

    it "returns a hash with device, os, browser, ip_address, and last_seen_at" do
      expect(session.info).to match(
        {
          device: "Other",
          os: "Windows 10",
          browser: "Chrome 58.0.3029.110",
          ip_address: "1.2.3.4",
          last_seen_at: be_within(3.seconds).of(Time.current)
        }
      )
    end
  end

  describe "#shapeshifted?" do
    subject { session.shapeshifted? }

    let(:session) { described_class.new(original_authenticatable:) }

    context "when shapeshifted_at is present" do
      let(:original_authenticatable) { User.new }

      it { is_expected.to be true }
    end

    context "when shapeshifted_at is nil" do
      let(:original_authenticatable) { nil }

      it { is_expected.to be false }
    end
  end

  describe "#true_identity" do
    subject { session.true_identity }

    let(:session) { described_class.new(original_authenticatable:, authenticatable:) }
    let(:authenticatable) { User.new }

    context "original_authenticatable is present" do
      let(:original_authenticatable) { User.new }

      it { is_expected.to be original_authenticatable }
    end

    context "when original_authenticatable is nil" do
      let(:original_authenticatable) { nil }

      it { is_expected.to be authenticatable }
    end
  end

  describe "#shapeshift" do
    subject { session.shapeshift(user) }

    context "when user is not valid" do
      let(:session) { described_class.new }
      let(:user) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::InvalidArgumentError, "Expected an instance of User, got `nil`")
      end
    end

    context "when user is valid" do
      let(:session) do
        described_class.create!(
          expires_at: 1.hour.from_now,
          authenticatable: original_user,
          hashed_token: "foo",
          last_seen_at: Time.current
        )
      end
      let(:original_user) { User.create! }
      let(:user) { User.create! }

      it "updates the session with the new user and sets shapeshifted_at" do
        expect { subject }
          .to change(session, :shapeshifted_at).from(nil).to(be_within(3.seconds).of(Time.current))
          .and change(session, :original_authenticatable).from(nil).to(original_user)
          .and change(session, :authenticatable).from(original_user).to(user)
      end
    end
  end

  describe "#to_true_identity" do
    subject { session.to_true_identity }

    let(:session) do
      described_class.create!(
        expires_at: 1.hour.from_now,
        authenticatable: user,
        original_authenticatable: original_user,
        shapeshifted_at: Time.current,
        hashed_token: "foo",
        last_seen_at: Time.current
      )
    end
    let(:original_user) { User.create! }
    let(:user) { User.create! }

    it "reverts the session to the original user and clears shapeshifted_at" do
      expect { subject }
        .to change(session, :shapeshifted_at).from(be_within(3.seconds).of(Time.current)).to(nil)
        .and change(session, :authenticatable).from(user).to(original_user)
        .and change(session, :original_authenticatable).from(original_user).to(nil)
    end
  end

  describe "#identity" do
    subject { session.identity }

    let(:session) { described_class.new(authenticatable:) }
    let(:authenticatable) { User.new }

    it { is_expected.to be authenticatable }
  end

  describe "#tenant" do
    subject { session.tenant }

    context "when tenant_type and tenant_id are both nil" do
      let(:session) { described_class.new(tenant_type: nil, tenant_id: nil) }

      it { is_expected.to be_nil }
    end

    context "when tenant_type is present and tenant_id is nil" do
      let(:session) { described_class.new(tenant_type: "subdomain", tenant_id: nil) }

      it { is_expected.to eq("subdomain") }
    end

    context "when tenant_type and tenant_id are both present" do
      let(:tenant) { Company.create! }
      let(:session) { described_class.new(tenant_type: tenant.class.to_s, tenant_id: tenant.id) }

      it { is_expected.to eq(tenant) }
    end
  end

  describe ".establish" do
    subject { described_class.establish(authenticatable, request, **tenant) }

    let(:tenant) { { tenant_type: "subdomain", tenant_id: nil } }
    let(:request) { ActionDispatch::Request.new("REMOTE_ADDR" => "1.2.3.4", "HTTP_USER_AGENT" => "IE7") }

    context "when authenticatable is valid" do
      let(:authenticatable) { User.create! }

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

  describe ".prune" do
    subject { described_class.prune }

    let!(:session1) do
      described_class.create!(
        expires_at: 1.hour.from_now,
        authenticatable: User.create!,
        hashed_token: "foo",
        last_seen_at: 10.minutes.ago
      )
    end
    let!(:session2) do
      described_class.create!(
        expires_at: 1.hour.from_now,
        authenticatable: User.create!,
        hashed_token: "bar",
        last_seen_at: 3.minutes.ago,
        tenant_type: "subdomain",
        tenant_id: nil
      )
    end

    before do
      Array.new(3) do |i|
        described_class.create!(
          expires_at: 1.hour.ago,
          authenticatable: User.create!,
          hashed_token: "foo#{i}",
          last_seen_at: 10.minutes.ago
        )
        described_class.create!(
          expires_at: 1.hour.from_now,
          authenticatable: User.create!,
          hashed_token: "bar#{i}",
          last_seen_at: 10.minutes.ago,
          tenant_type: "Company",
          tenant_id: 42
        )
      end
    end

    it "deletes all expired sessions and sessions with missing tenants" do
      expect { subject }.to change(described_class, :count).from(8).to(2)
      expect(described_class.where(id: [session1.id, session2.id])).to all(be_persisted)
    end

    context "when inactive session lifetime is set" do
      before { Veri::Configuration.configure { _1.inactive_session_lifetime = 5.minutes } }

      it "deletes sessions that are both expired and inactive" do
        expect { subject }.to change(described_class, :count).from(8).to(1)
        expect(described_class.where(id: session2.id)).to all(be_persisted)
      end
    end
  end

  describe ".terminate_all" do
    subject { described_class.terminate_all(authenticatable) }

    context "when authenticatable is invalid" do
      let(:authenticatable) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::InvalidArgumentError, "Expected an instance of User, got `nil`")
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
