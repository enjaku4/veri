RSpec.describe Veri::Authenticatable do
  describe "included" do
    it "raises an error if included more than once" do
      expect { Client.include(described_class) }.to raise_error(Veri::Error, "Veri::Authenticatable can only be included once")
    end
  end

  describe ".suspended" do
    let!(:suspended_user) { User.create!(suspended: true) }

    before { User.create!(suspended: false) }

    it "returns only suspended users" do
      expect(User.suspended).to contain_exactly(suspended_user)
    end
  end

  describe ".unsuspended" do
    let!(:unsuspended_user) { User.create!(suspended: false) }

    before { User.create!(suspended: true) }

    it "returns only unsuspended users" do
      expect(User.unsuspended).to contain_exactly(unsuspended_user)
    end
  end

  describe "#sessions" do
    let(:user) { User.create! }
    let!(:sessions) do
      Array.new(3) do |i|
        Veri::Session.create!(
          authenticatable: user,
          expires_at: 1.hour.ago + i.hours,
          hashed_token: "foo#{i}",
          last_seen_at: Time.current
        )
      end
    end

    it "returns all sessions for the authenticatable" do
      expect(user.sessions).to match_array(sessions)
    end
  end

  describe "#update_password" do
    subject { user.update_password(password) }

    let(:user) { User.create! }
    let(:other_user) { User.create! }

    before do
      [user, user, other_user].each do |authenticatable|
        Veri::Session.create!(
          hashed_token: SecureRandom.hex,
          expires_at: 1.hour.from_now,
          last_seen_at: Time.current,
          authenticatable:
        )
      end
    end

    context "when the password is invalid" do
      let(:password) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::InvalidArgumentError, "Expected a non-empty string, got `nil`")
      end

      it "does not terminate sessions" do
        expect { subject }.to raise_error(Veri::InvalidArgumentError)
        expect(Veri::Session.count).to eq(3)
      end
    end

    context "when the password is valid" do
      let(:password) { "new_password" }

      before { allow(Veri::Configuration.hasher).to receive(:create).with(password).and_return("hashed_password") }

      it "updates the hashed password and password updated at timestamp" do
        expect { subject }
          .to change(user, :hashed_password).from(nil).to("argon2:hashed_password")
          .and change(user, :password_updated_at).from(nil).to be_within(1.second).of(Time.current)
      end

      it "returns true" do
        expect(subject).to be true
      end

      it "terminates all sessions of the user and no one else's" do
        expect { subject }.to change(user.sessions, :count).from(2).to(0)
        expect(other_user.sessions.count).to eq(1)
      end

      context "when terminate_sessions is false" do
        subject { user.update_password(password, terminate_sessions: false) }

        it "updates the password and keeps the sessions" do
          expect { subject }.to change(user, :hashed_password).from(nil).to("argon2:hashed_password")
          expect(user.sessions.count).to eq(2)
        end
      end

      context "when the hashing algorithm changes after the user has already hashed a password" do
        before do
          allow(Veri::Configuration.hasher).to receive(:create).and_call_original
          user.update_password("old_password")
          Veri::Configuration.configure { _1.hashing_algorithm = :bcrypt }
        end

        it "hashes the password with the newly configured algorithm" do
          subject
          expect(user.hashed_password).to start_with("bcrypt:$2")
          expect(user.verify_password(password)).to be true
        end
      end

      context "when the user is a new record" do
        let(:new_user) { User.new }

        it "saves the user with the password" do
          expect(new_user.update_password(password)).to be true
          expect(new_user.reload.hashed_password).to eq("argon2:hashed_password")
        end
      end
    end

    context "when events are enabled" do
      before do
        Veri::Configuration.configure { _1.events_enabled = true }
        allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
      end

      let(:admin) { User.create! }

      it "publishes change_password and terminate_session for each session it ends" do
        sessions = user.sessions.to_a

        user.update_password("password", actor: admin)

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("change_password.veri", { identity: user, actor: admin })
        sessions.each do |session|
          expect(ActiveSupport::Notifications).to have_received(:instrument).with("terminate_session.veri", { session:, identity: user, actor: admin, tenant: nil })
        end
      end

      it "publishes only change_password with a nil actor when sessions are kept" do
        user.update_password("password", terminate_sessions: false)

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("change_password.veri", { identity: user, actor: nil })
        expect(ActiveSupport::Notifications).not_to have_received(:instrument).with("terminate_session.veri", anything)
      end
    end
  end

  describe "#password_set?" do
    subject { user.password_set? }

    context "when the user has a password" do
      let(:user) { User.create!(hashed_password: "argon2:$argon2id$hashed_password") }

      it { is_expected.to be true }
    end

    context "when the user has no password" do
      let(:user) { User.create! }

      it { is_expected.to be false }
    end
  end

  describe "#verify_password" do
    subject { user.verify_password(password) }

    let(:user) { User.create!(hashed_password: "argon2:$argon2id$hashed_password") }

    context "when the password is invalid" do
      let(:password) { nil }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::InvalidArgumentError, "Expected a non-empty string, got `nil`")
      end
    end

    context "when the password is incorrect" do
      let(:password) { "wrong_password" }

      before { allow(Veri::Configuration.hasher).to receive(:verify).with(password, "$argon2id$hashed_password").and_return(false) }

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "when the user has no password" do
      let(:user) { User.create!(hashed_password: nil) }
      let(:password) { "some_password" }

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "when the password is correct" do
      let(:password) { "correct_password" }

      before { allow(Veri::Configuration.hasher).to receive(:verify).with(password, "$argon2id$hashed_password").and_return(true) }

      it "returns true" do
        expect(subject).to be true
      end

      it "does not re-hash the password" do
        expect { subject }.not_to(change { user.reload.hashed_password })
      end
    end

    context "when the stored hash was created with a different algorithm" do
      let(:user) { User.create!(hashed_password: "bcrypt:#{Veri::Password::BCrypt.create("secure_password")}") }

      before { Veri::Configuration.configure { _1.hashing_algorithm = :pbkdf2 } }

      context "when the password is correct" do
        let(:password) { "secure_password" }

        it "verifies with the stored algorithm and re-hashes with the configured one" do
          expect(subject).to be true
          expect(user.reload.hashed_password).to start_with("pbkdf2:sha512$")
          expect(user.verify_password(password)).to be true
        end

        it "does not change password_updated_at" do
          expect { subject }.not_to(change { user.reload.password_updated_at })
        end

        it "re-hashes with the algorithm configured after the user has already verified a password" do
          subject
          Veri::Configuration.configure { _1.hashing_algorithm = :scrypt }

          expect(user.verify_password(password)).to be true
          expect(user.hashed_password).to start_with("scrypt:")
          expect(user.verify_password(password)).to be true
        end

        it "does not terminate sessions" do
          Veri::Session.create!(
            hashed_token: SecureRandom.hex,
            expires_at: 1.hour.from_now,
            last_seen_at: Time.current,
            authenticatable: user
          )

          expect { subject }.not_to(change { user.sessions.count })
        end
      end

      context "when the password is incorrect" do
        let(:password) { "wrong_password" }

        it "returns false and keeps the stored hash" do
          expect(subject).to be false
          expect(user.reload.hashed_password).to start_with("bcrypt:$2")
        end
      end
    end

    context "when the stored hash format is unrecognized" do
      let(:user) { User.create!(hashed_password: "garbage") }
      let(:password) { "secure_password" }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::Error, "Unrecognized password hash format")
      end
    end

    context "when the stored hash has no algorithm marker" do
      let(:user) { User.create!(hashed_password: Veri::Password::BCrypt.create("secure_password")) }
      let(:password) { "secure_password" }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::Error, "Unrecognized password hash format")
      end
    end

    Veri::Configuration::HASHERS.each_key do |algorithm|
      context "with #{algorithm} hashing algorithm" do
        let(:user) { User.create! }

        before do
          Veri::Configuration.configure { _1.hashing_algorithm = algorithm }
          user.update_password("secure_password")
        end

        it "stores the hash with the algorithm marker and verifies against it" do
          expect(user.hashed_password).to start_with("#{algorithm}:")
          expect(user.verify_password("secure_password")).to be true
          expect(user.verify_password("wrong_password")).to be false
        end
      end
    end
  end

  describe "#suspend!" do
    subject { user.suspend! }

    let(:user) { User.create! }

    it "suspends the user and sets suspended_at timestamp" do
      expect { subject }
        .to change(user, :suspended).from(false).to(true)
        .and change(user, :suspended_at).from(nil).to be_within(1.second).of(Time.current)
    end

    it "terminates all sessions of the user" do
      2.times do
        Veri::Session.create!(
          hashed_token: SecureRandom.hex,
          expires_at: 1.hour.from_now,
          last_seen_at: Time.current,
          authenticatable: user
        )
      end

      expect { subject }.to change(user.sessions, :count).from(2).to(0)
    end

    context "when events are enabled" do
      before do
        Veri::Configuration.configure { _1.events_enabled = true }
        allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
      end

      let(:admin) { User.create! }

      it "publishes suspend_account and terminate_session for each session it ends" do
        sessions = Array.new(2) do
          Veri::Session.create!(
            authenticatable: user,
            hashed_token: SecureRandom.hex,
            expires_at: 1.hour.from_now,
            last_seen_at: Time.current
          )
        end

        user.suspend!(actor: admin)

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("suspend_account.veri", { identity: user, actor: admin })
        sessions.each do |session|
          expect(ActiveSupport::Notifications).to have_received(:instrument).with("terminate_session.veri", { session:, identity: user, actor: admin, tenant: nil })
        end
      end

      it "publishes suspend_account with a nil actor" do
        user.suspend!

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("suspend_account.veri", { identity: user, actor: nil })
      end
    end
  end

  describe "#unsuspend!" do
    subject { user.unsuspend! }

    let(:user) { User.create!(suspended: true, suspended_at: 1.hour.ago) }

    it "unsuspends the user and clears suspended_at timestamp" do
      expect { subject }
        .to change(user, :suspended).from(true).to(false)
        .and change(user, :suspended_at).from(be_present).to(nil)
    end

    context "when events are enabled" do
      before do
        Veri::Configuration.configure { _1.events_enabled = true }
        allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
      end

      let(:admin) { User.create! }

      it "publishes unsuspend_account" do
        user.unsuspend!(actor: admin)

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("unsuspend_account.veri", { identity: user, actor: admin })
      end

      it "publishes unsuspend_account with a nil actor" do
        user.unsuspend!

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("unsuspend_account.veri", { identity: user, actor: nil })
      end
    end
  end

  describe "Active Record row locking" do
    let(:user) { User.create! }

    before do
      Veri::Session.create!(
        hashed_token: SecureRandom.hex,
        expires_at: 1.hour.from_now,
        last_seen_at: Time.current,
        authenticatable: user
      )
    end

    it "does not suspend the user or terminate sessions on with_lock" do
      expect(user.with_lock { :locked }).to eq(:locked)
      expect(user.reload).not_to be_suspended
      expect(user.sessions.count).to eq(1)
    end

    it "does not suspend the user or terminate sessions on lock!" do
      user.lock!

      expect(user.reload).not_to be_suspended
      expect(user.sessions.count).to eq(1)
    end
  end

  describe "#suspended?" do
    subject { user.suspended? }

    context "when user is not suspended" do
      let(:user) { User.create!(suspended: false) }

      it "returns false" do
        expect(subject).to be false
      end
    end

    context "when user is suspended" do
      let(:user) { User.create!(suspended: true) }

      it "returns true" do
        expect(subject).to be true
      end
    end
  end
end
