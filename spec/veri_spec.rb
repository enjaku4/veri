RSpec.describe Veri do
  describe "version" do
    it "has a version number" do
      expect(Veri::VERSION).not_to be_nil
    end
  end

  describe ".configure" do
    let(:config) { Veri::Configuration }

    context "when not configured" do
      it "has default configurations" do
        expect(config.hashing_algorithm).to eq(:argon2)
        expect(config.inactive_session_lifetime).to be_nil
        expect(config.total_session_lifetime).to eq(14.days)
        expect(config.user_model_name).to eq("User")
        expect(config.hasher).to eq(Veri::Password::Argon2)
        expect(config.user_model).to eq(User)
      end
    end

    context "when configured" do
      before do
        described_class.configure do |config|
          config.hashing_algorithm = :bcrypt
          config.inactive_session_lifetime = 30.minutes
          config.total_session_lifetime = 7.days
          config.user_model_name = "Client"
        end
      end

      it "applies custom configurations" do
        expect(config.hashing_algorithm).to eq(:bcrypt)
        expect(config.inactive_session_lifetime).to eq(30.minutes)
        expect(config.total_session_lifetime).to eq(7.days)
        expect(config.user_model_name).to eq("Client")
        expect(config.hasher).to eq(Veri::Password::BCrypt)
        expect(config.user_model).to eq(Client)
      end
    end

    context "when misconfigured" do
      context "hashing algorithm" do
        it "raises an error" do
          expect { described_class.configure { _1.hashing_algorithm = :invalid } }.to raise_error(
            Veri::ConfigurationError,
            "Invalid hashing algorithm `:invalid`, supported algorithms are: argon2, bcrypt, pbkdf2, scrypt"
          )
        end
      end

      context "inactive session lifetime" do
        it "raises an error" do
          expect { described_class.configure { _1.inactive_session_lifetime = "invalid" } }.to raise_error(
            Veri::ConfigurationError,
            "Invalid inactive session lifetime `\"invalid\"`, expected an instance of ActiveSupport::Duration or nil"
          )
        end
      end

      context "total session lifetime" do
        it "raises an error" do
          expect { described_class.configure { _1.total_session_lifetime = 10 } }.to raise_error(
            Veri::ConfigurationError,
            "Invalid total session lifetime `10`, expected an instance of ActiveSupport::Duration"
          )
        end
      end

      context "user model name" do
        before { described_class.configure { _1.user_model_name = model_name } }

        context "when class does not exist" do
          let(:model_name) { "Foo" }

          it "raises an error" do
            expect { config.user_model }.to raise_error(
              Veri::ConfigurationError,
              "Invalid user model name `Foo`, expected an ActiveRecord model name as a string"
            )
          end
        end

        context "when class is not a subclass of ActiveRecord::Base" do
          let(:model_name) { "Veri" }

          it "raises an error" do
            expect { config.user_model }.to raise_error(
              Veri::ConfigurationError,
              "Invalid user model name `Veri`, expected an ActiveRecord model name as a string"
            )
          end
        end
      end
    end
  end
end
