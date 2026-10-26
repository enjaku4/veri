module Veri
  module Inputs
    class Boolean < Veri::Inputs::Base
      private

      def validate_and_normalize = [true, false].include?(@value) ? @value : raise_error
    end
  end
end
