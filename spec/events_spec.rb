RSpec.describe Veri::Events do
  let!(:user) { User.create! }
  let!(:admin) { User.create! }
  let(:controller) { DummyController.new.tap { _1.request = ActionDispatch::TestRequest.create } }

  def create_session(authenticatable = user, **attributes)
    Veri::Session.create!(
      hashed_token: SecureRandom.hex,
      expires_at: 1.hour.from_now,
      last_seen_at: Time.current,
      authenticatable:,
      **attributes
    )
  end

  def published
    received = []
    subscriber = ActiveSupport::Notifications.subscribe(/\.veri\z/) { |event| received << [event.name, event.payload] }
    yield
    received
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  context "when events are disabled" do
    it "publishes nothing and does not require an actor" do
      session = create_session

      events = published do
        controller.log_in(user)
        controller.log_out
        session.switch_tenant("acme")
        session.terminate
        create_session.tap { _1.shapeshift(admin) }.to_true_identity
        user.sessions.terminate_all
        user.update_password("password")
        user.suspend!
        user.unsuspend!
      end

      expect(events).to be_empty
    end
  end

  context "when events are enabled" do
    before { Veri::Configuration.configure { _1.events_enabled = true } }

    it "publishes establish_session with the new session on log_in" do
      events = published { controller.log_in(user, tenant: "acme") }

      expect(events).to eq([["establish_session.veri", { session: user.sessions.take }]])
    end

    it "publishes terminate_session on log_out with the session owner as the actor" do
      controller.log_in(user)
      session = user.sessions.take

      events = published { controller.log_out }

      expect(events).to eq([["terminate_session.veri", { session:, actor: user }]])
      expect(Veri::Session.exists?(session.id)).to be false
    end

    it "publishes terminate_session on log_out with the impersonating admin as the actor" do
      controller.log_in(admin)
      session = controller.current_session
      session.shapeshift(user)

      events = published { controller.log_out }

      expect(events).to eq([["terminate_session.veri", { session:, actor: admin }]])
    end

    it "publishes nothing on log_out without a session" do
      expect(published { controller.log_out }).to be_empty
    end

    it "publishes terminate_session with the session and the actor" do
      session = create_session

      events = published { session.terminate(actor: admin) }

      expect(events).to eq([["terminate_session.veri", { session:, actor: admin }]])
      expect(Veri::Session.exists?(session.id)).to be false
    end

    it "publishes terminate_session for each session terminated in bulk" do
      sessions = Array.new(3) { create_session }
      other_session = create_session(admin)
      result = nil

      events = published { result = user.sessions.terminate_all(actor: admin) }

      expect(events).to match_array(sessions.map { ["terminate_session.veri", { session: _1, actor: admin }] })
      expect(result).to eq(3)
      expect(Veri::Session.all).to contain_exactly(other_session)
    end

    it "publishes switch_tenant with the session and the previous tenant" do
      company = Company.create!
      another_company = Company.create!
      session = create_session(tenant: company)

      events = published { session.switch_tenant(another_company) }

      expect(events).to eq([["switch_tenant.veri", { session:, previous_tenant: company }]])
      expect(session.reload.tenant).to eq(another_company)
    end

    it "publishes start_impersonation and end_impersonation" do
      session = create_session(admin)

      started = published { session.shapeshift(user) }
      ended = published { session.to_true_identity }

      expect(started).to eq([["start_impersonation.veri", { session:, impersonator: admin, impersonated_user: user }]])
      expect(ended).to eq([["end_impersonation.veri", { session:, impersonator: admin, impersonated_user: user }]])
    end

    it "publishes change_password and terminate_session for each session it ends" do
      sessions = Array.new(2) { create_session }

      events = published { user.update_password("password", actor: admin) }

      expect(events).to match_array(
        [["change_password.veri", { user:, actor: admin }]] + sessions.map { ["terminate_session.veri", { session: _1, actor: admin }] }
      )
      expect(user.sessions.count).to eq(0)
    end

    it "publishes only change_password when sessions are kept" do
      create_session

      events = published { user.update_password("password", terminate_sessions: false, actor: admin) }

      expect(events).to eq([["change_password.veri", { user:, actor: admin }]])
    end

    it "publishes suspend_account and terminate_session for each session it ends" do
      sessions = Array.new(2) { create_session }

      events = published { user.suspend!(actor: admin) }

      expect(events).to match_array(
        [["suspend_account.veri", { user:, actor: admin }]] + sessions.map { ["terminate_session.veri", { session: _1, actor: admin }] }
      )
      expect(user.sessions.count).to eq(0)
    end

    it "publishes unsuspend_account" do
      events = published { user.unsuspend!(actor: admin) }

      expect(events).to eq([["unsuspend_account.veri", { user:, actor: admin }]])
    end

    it "publishes nothing when the surrounding transaction is rolled back" do
      events = published do
        ActiveRecord::Base.transaction do
          user.suspend!(actor: admin)
          raise ActiveRecord::Rollback
        end
      end

      expect(events).to be_empty
      expect(user.reload.suspended?).to be false
    end

    it "publishes once the surrounding transaction is committed" do
      events = published do
        ActiveRecord::Base.transaction { user.suspend!(actor: admin) }
      end

      expect(events).to eq([["suspend_account.veri", { user:, actor: admin }]])
    end

    describe "missing actor" do
      let(:message) { "Actor is required when events are enabled" }

      it "raises on update_password and keeps the password" do
        expect { user.update_password("password") }.to raise_error(Veri::InvalidArgumentError, message)
        expect(user.reload.password_set?).to be false
      end

      it "raises on suspend! and keeps the account active" do
        expect { user.suspend! }.to raise_error(Veri::InvalidArgumentError, message)
        expect(user.reload.suspended?).to be false
      end

      it "raises on unsuspend! and keeps the account suspended" do
        user.update!(suspended: true)

        expect { user.unsuspend! }.to raise_error(Veri::InvalidArgumentError, message)
        expect(user.reload.suspended?).to be true
      end

      it "raises on terminate and keeps the session" do
        session = create_session

        expect { session.terminate }.to raise_error(Veri::InvalidArgumentError, message)
        expect(Veri::Session.exists?(session.id)).to be true
      end

      it "raises on terminate_all and keeps the sessions" do
        create_session

        expect { user.sessions.terminate_all }.to raise_error(Veri::InvalidArgumentError, message)
        expect(user.sessions.count).to eq(1)
      end
    end
  end
end
