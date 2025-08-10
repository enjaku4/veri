module Veri
  module Inputs
    class NonEmptyString < Veri::Inputs::Base
      private

      def type = -> { self.class::Strict::String.constrained(min_size: 1) }
    end
  end
end
