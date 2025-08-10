module Veri
  module Inputs
    class Duration < Veri::Inputs::Base
      private

      def type = -> { self.class::Instance(ActiveSupport::Duration) }
    end
  end
end
