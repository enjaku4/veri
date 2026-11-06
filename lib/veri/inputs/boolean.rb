module Veri
  module Inputs
    class Boolean < Veri::Inputs::Base
      private

      def default_message = "Expected true or false, got `#{@value.inspect}`"

      def validate_and_normalize = [true, false].include?(@value) ? @value : raise_error
    end
  end
end
