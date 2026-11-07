module Veri
  module Inputs
    class Request < Veri::Inputs::Base
      private

      def default_message = "Expected an instance of ActionDispatch::Request, got `#{@value.inspect}`"

      def validate_and_normalize = @value.is_a?(ActionDispatch::Request) ? @value : raise_error
    end
  end
end
