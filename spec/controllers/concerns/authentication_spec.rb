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

    context "when the user account is locked" do
      let(:user) { User.create!(locked: true) }

      it "returns false and does not log in the user" do
        expect(subject).to be false
        expect(controller.current_user).to be_nil
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

    before { allow(controller).to receive_messages(current_user: user, logged_in?: true, shapeshifter?: true, current_session: session) }

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
  end
end
