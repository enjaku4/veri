module Veri
  module Inputs
    class NonEmptyString < Veri::Inputs::Base
      private

      def processor = -> { @value.is_a?(String) && !@value.empty? ? @value : raise_error }
    end
  end
end
