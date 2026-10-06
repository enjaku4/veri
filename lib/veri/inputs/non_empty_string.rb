module Veri
  module Inputs
    class NonEmptyString < Veri::Inputs::Base
      private

      def default_message = "Expected a non-empty string, got `#{@value.inspect}`"

      def processor = -> { @value.is_a?(String) && !@value.empty? ? @value : raise_error }
    end
  end
end
