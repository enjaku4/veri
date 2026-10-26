module Veri
  module Inputs
    class Authenticatable < Veri::Inputs::Base
      private

      def default_message = "Expected an instance of #{Veri::Configuration.user_model_name}, got `#{@value.inspect}`"

      def validate_and_normalize = @value.is_a?(Veri::Configuration.user_model) ? @value : raise_error
    end
  end
end
