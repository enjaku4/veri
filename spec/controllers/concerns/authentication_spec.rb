RSpec.describe Veri::Authentication do
  describe ".with_authentication" do
    it "passes the options to before_action" do
      expect(DummyController).to receive(:before_action).with(:with_authentication, only: [:index, :show], if: :foo?)
      DummyController.with_authentication(only: [:index, :show], if: :foo?)
    end

    context "when ArgumentError is raised" do
      before { allow(DummyController).to receive(:before_action).and_raise(ArgumentError, "No before_action found") }

      it "re-raises the error" do
        expect { DummyController.with_authentication(only: [:index, :show], if: :foo?) }
          .to raise_error(Veri::Error, "No before_action found")
      end
    end
  end

  describe ".skip_authentication" do
    it "passes the options to skip_before_action" do
      expect(DummyController).to receive(:skip_before_action).with(:with_authentication, only: [:index, :show], if: :foo?)
      DummyController.skip_authentication(only: [:index, :show], if: :foo?)
    end

    context "when ArgumentError is raised" do
      before { allow(DummyController).to receive(:skip_before_action).and_raise(ArgumentError, "No before_action found") }

      it "re-raises the error" do
        expect { DummyController.skip_authentication(only: [:index, :show], if: :foo?) }
          .to raise_error(Veri::Error, "No before_action found")
      end
    end
  end

  describe "#current_user" do
    subject { controller.current_user }

    let(:controller) { DummyController.new }

    before { controller.request = ActionDispatch::TestRequest.create }

    context "when user is logged in" do
      let(:user) { User.create! }

      before { controller.log_in(user) }

      it { is_expected.to eq(user) }
    end

    context "when user is not logged in" do
      it { is_expected.to be_nil }
    end

    context "when the session is shapeshifted within the same request" do
      let(:user) { User.create! }
      let(:another_user) { User.create! }

      before do
        controller.log_in(user)
        controller.current_user
        controller.current_session.shapeshift(another_user)
      end

      it "returns the assumed identity" do
        expect(subject).to eq(another_user)
      end

      it "returns the original user after reverting to the true identity" do
        controller.current_session.to_true_identity
        expect(subject).to eq(user)
      end
    end

    context "when the session is expired" do
      let(:user) { User.create! }

      before { controller.log_in(user) }

      it "returns nil" do
        travel_to(Veri::Configuration.total_session_lifetime.from_now + 1.minute) do
          expect(subject).to be_nil
        end
      end
    end

    context "when the session is inactive" do
      let(:user) { User.create! }

      before do
        Veri::Configuration.configure { _1.inactive_session_lifetime = 1.hour }
        controller.log_in(user)
      end

      it "returns nil" do
        travel_to(2.hours.from_now) do
          expect(subject).to be_nil
        end
      end
    end
  end

  describe "#current_session" do
    subject { controller.current_session }

    let(:controller) { DummyController.new }

    before { controller.request = ActionDispatch::TestRequest.create }

    context "when user is logged in" do
      let(:user) { User.create! }

      before { controller.log_in(user) }

      it "returns the current session" do
        expect(subject).to eq(user.sessions.take)
      end
    end

    context "when user is not logged in" do
      it { is_expected.to be_nil }
    end

    context "when user is logged in to a tenant" do
      let(:user) { User.create! }
      let(:company) { Company.create! }

      before { controller.log_in(user, tenant: company) }

      it "returns the current session" do
        expect(subject).to eq(user.sessions.take)
      end

      context "when the tenant has been deleted" do
        before { company.destroy! }

        it "returns the current session" do
          expect(subject).to eq(user.sessions.take)
        end
      end
    end
  end

  describe "#current_tenant" do
    subject { controller.current_tenant }

    let(:controller) { DummyController.new }
    let(:user) { User.create! }

    before { controller.request = ActionDispatch::TestRequest.create }

    context "when user is not logged in" do
      it "raises an error" do
        expect { subject }.to raise_error(Veri::Error, "No user is logged in")
      end
    end

    context "when user is logged in without a tenant" do
      before { controller.log_in(user) }

      it { is_expected.to be_nil }
    end

    context "when user is logged in to a string tenant" do
      before { controller.log_in(user, tenant: "subdomain") }

      it { is_expected.to eq("subdomain") }
    end

    context "when user is logged in to a model tenant" do
      let(:company) { Company.create! }

      before { controller.log_in(user, tenant: company) }

      it { is_expected.to eq(company) }

      context "when the session is switched to another tenant" do
        let(:another_company) { Company.create! }

        before { controller.current_session.switch_tenant(another_company) }

        it { is_expected.to eq(another_company) }
      end

      context "when the tenant has been deleted" do
        before { company.destroy! }

        it "raises an error" do
          expect { subject }.to raise_error(Veri::Error, "Tenant not found")
        end
      end

      context "when the tenant class no longer exists" do
        before { user.sessions.update_all(tenant_type: "NonExistentClass") }

        it "raises an error" do
          expect { subject }.to raise_error(NameError, "uninitialized constant NonExistentClass")
        end
      end
    end
  end

  describe "#log_in" do
    subject { controller.log_in(user) }

    let(:controller) { DummyController.new }
    let(:user) { User.create! }

    before { controller.request = ActionDispatch::TestRequest.create }

    it "logs in the user and returns true" do
      expect(subject).to be true
      expect(controller.current_user).to eq(user)
    end

    context "when the user is not an instance of the configured user model" do
      let(:user) { 123 }

      it "raises an error" do
        expect { subject }.to raise_error(Veri::InvalidArgumentError, "Expected an instance of User, got `123`")
      end
    end

    context "when the user account is suspended" do
      let(:user) { User.create!(suspended: true) }

      it "returns false and does not log in the user" do
        expect(subject).to be false
        expect(controller.current_user).to be_nil
      end
    end

    context "when the request is over HTTPS" do
      before { controller.request = ActionDispatch::TestRequest.create("HTTPS" => "on") }

      it "sets the secure flag on the auth cookie" do
        subject
        expect(controller.send(:cookies).instance_variable_get(:@set_cookies)["veri_token"][:secure]).to be true
      end
    end

    context "when the request is over HTTP" do
      it "does not set the secure flag on the auth cookie" do
        subject
        expect(controller.send(:cookies).instance_variable_get(:@set_cookies)["veri_token"][:secure]).to be false
      end
    end

    context "when current user was read before logging in" do
      before { controller.current_user }

      it "returns the logged in user within the same request" do
        subject
        expect(controller.current_user).to eq(user)
        expect(controller.logged_in?).to be true
      end
    end

    context "when another user is already logged in within the same request" do
      let(:another_user) { User.create! }

      before do
        controller.log_in(another_user)
        controller.current_user
      end

      it "returns the newly logged in user and their session" do
        subject
        expect(controller.current_user).to eq(user)
        expect(controller.current_session).to eq(user.sessions.take)
      end
    end

    context "when the user logs in again after updating their password within the same request" do
      before do
        controller.log_in(user)
        controller.current_user
        user.update_password("new_password")
      end

      it "returns the new session" do
        subject
        expect(controller.current_session).to eq(user.sessions.take)
        expect(controller.logged_in?).to be true
      end
    end

    it "creates a session without a tenant" do
      subject
      expect(controller.current_session).to have_attributes(tenant_type: nil, tenant_id: nil)
    end

    context "when a model tenant is given" do
      subject { controller.log_in(user, tenant: company) }

      let(:company) { Company.create! }

      it "logs in the user to the tenant" do
        expect(subject).to be true
        expect(controller.current_session.tenant).to eq(company)
      end
    end

    context "when a string tenant is given" do
      subject { controller.log_in(user, tenant: "subdomain") }

      it "logs in the user to the tenant" do
        expect(subject).to be true
        expect(controller.current_session.tenant).to eq("subdomain")
      end
    end

    context "when the tenant is invalid" do
      subject { controller.log_in(user, tenant: 123) }

      it "raises an error" do
        expect { subject }.to raise_error(
          Veri::InvalidTenantError, "Expected a string, an ActiveRecord model instance, or nil, got `123`"
        )
      end
    end

    context "when events are enabled" do
      before do
        Veri::Configuration.configure { _1.events_enabled = true }
        allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
      end

      let(:admin) { User.create! }

      it "publishes establish_session with the new session on log_in" do
        controller.log_in(user, tenant: "acme")

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("establish_session.veri", { session: user.sessions.take, identity: user, actor: user, tenant: "acme" })
      end

      it "publishes establish_session with an overridden actor on log_in" do
        controller.log_in(user, actor: admin)

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("establish_session.veri", { session: user.sessions.take, identity: user, actor: admin, tenant: nil })
      end

      it "publishes establish_session with an explicitly nil actor on log_in" do
        controller.log_in(user, actor: nil)

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("establish_session.veri", { session: user.sessions.take, identity: user, actor: nil, tenant: nil })
      end
    end
  end

  describe "#log_out" do
    subject { controller.log_out }

    let(:controller) { DummyController.new }
    let(:user) { User.create! }

    before do
      controller.request = ActionDispatch::TestRequest.create
      controller.log_in(user)
    end

    it "logs out the user" do
      expect { subject }.to change(user.sessions, :count).from(1).to(0)
    end

    it "deletes the veri_token cookie" do
      expect { subject }.to change { controller.send(:cookies).encrypted["veri_token"] }.from(be_present).to(be_nil)
    end

    it "resets the current user and session within the same request" do
      expect(controller.current_user).to eq(user)
      subject
      expect(controller.current_user).to be_nil
      expect(controller.current_session).to be_nil
      expect(controller.logged_in?).to be false
    end

    context "when events are enabled" do
      before do
        Veri::Configuration.configure { _1.events_enabled = true }
        allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
      end

      let(:admin) { User.create! }

      it "publishes terminate_session on log_out with the session owner as the actor" do
        session = user.sessions.take

        controller.log_out

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("terminate_session.veri", { session:, identity: user, actor: user, tenant: nil })
      end

      it "publishes terminate_session on log_out with the impersonating admin as the actor" do
        controller.log_in(admin)
        session = controller.current_session
        session.shapeshift(user)

        controller.log_out

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("terminate_session.veri", { session:, identity: user, actor: admin, tenant: nil })
      end

      it "publishes terminate_session with an overridden actor on log_out during impersonation" do
        controller.log_in(admin)
        session = controller.current_session
        session.shapeshift(user)
        actor = "security job"

        controller.log_out(actor:)

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("terminate_session.veri", { session:, identity: user, actor:, tenant: nil })
      end

      it "publishes terminate_session with an explicitly nil actor on log_out during impersonation" do
        controller.log_in(admin)
        session = controller.current_session
        session.shapeshift(user)

        controller.log_out(actor: nil)

        expect(ActiveSupport::Notifications).to have_received(:instrument).with("terminate_session.veri", { session:, identity: user, actor: nil, tenant: nil })
      end

      it "publishes nothing on log_out without a session" do
        controller.log_out

        expect(ActiveSupport::Notifications).not_to receive(:instrument).with("terminate_session.veri", anything)
        controller.log_out
      end
    end
  end

  describe "#logged_in?" do
    subject { controller.logged_in? }

    let(:controller) { DummyController.new }

    before { controller.request = ActionDispatch::TestRequest.create }

    context "when user is logged in" do
      let(:user) { User.create! }

      before { controller.log_in(user) }

      it { is_expected.to be true }
    end

    context "when user is not logged in" do
      it { is_expected.to be false }
    end

    context "when session exists but user is missing" do
      before do
        user = User.create!
        controller.log_in(user)
        user.destroy!
      end

      it { is_expected.to be false }
    end

    context "when the session is expired" do
      before { controller.log_in(User.create!) }

      it "returns false" do
        travel_to(Veri::Configuration.total_session_lifetime.from_now + 1.minute) do
          expect(subject).to be false
        end
      end
    end

    context "when the session is inactive" do
      before do
        Veri::Configuration.configure { _1.inactive_session_lifetime = 1.hour }
        controller.log_in(User.create!)
      end

      it "returns false" do
        travel_to(2.hours.from_now) do
          expect(subject).to be false
        end
      end
    end
  end

  describe "#return_path" do
    subject { controller.return_path }

    let(:controller) { DummyController.new }

    before { controller.request = ActionDispatch::TestRequest.create }

    context "when return_path is set in cookies" do
      before { controller.send(:cookies).signed["veri_return_path"] = "/some/path" }

      it "returns the return path from the session" do
        expect(subject).to eq("/some/path")
      end
    end

    context "when return_path is not set in cookies" do
      it "returns nil" do
        expect(subject).to be_nil
      end
    end
  end

  describe "#shapeshifter?" do
    subject { controller.shapeshifter? }

    let(:controller) { DummyController.new }

    before { controller.request = ActionDispatch::TestRequest.create }

    context "when there is no current session" do
      it { is_expected.to be false }
    end

    context "when user has shapeshifted" do
      let(:user) { User.create! }

      before do
        controller.log_in(user)
        controller.current_session.shapeshift(user)
      end

      it { is_expected.to be true }
    end

    context "when user has not shapeshifted" do
      let(:user) { User.create! }

      before { controller.log_in(user) }

      it { is_expected.to be false }
    end

    context "when user has reverted to true identity" do
      let(:user) { User.create! }

      before do
        controller.log_in(user)
        controller.current_session.shapeshift(user)
        controller.current_session.to_true_identity
      end

      it { is_expected.to be false }
    end
  end

  describe "helper methods" do
    let(:controller) { DummyController.new }
    let(:view) { controller.view_context }
    let(:user) { User.create! }
    let(:session) { Veri::Session.new }

    before do
      allow(controller).to receive_messages(
        current_user: user, logged_in?: true, shapeshifter?: true, current_session: session, current_tenant: "subdomain"
      )
    end

    it "provides current_user helper method" do
      expect(view.current_user).to be user
    end

    it "provides logged_in? helper method" do
      expect(view.logged_in?).to be true
    end

    it "provides shapeshifter? helper method" do
      expect(view.shapeshifter?).to be true
    end

    it "provides current_session helper method" do
      expect(view.current_session).to be session
    end

    it "provides current_tenant helper method" do
      expect(view.current_tenant).to eq("subdomain")
    end
  end
end
