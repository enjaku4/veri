module Veri
  module Inputs
    class Boolean < Veri::Inputs::Base
      private

      def processor = -> { [true, false].include?(@value) ? @value : raise_error }
    end
  end
end
