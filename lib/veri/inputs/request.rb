module Veri
  module Inputs
    class Request < Veri::Inputs::Base
      private

      def type = -> { self.class::Instance(ActionDispatch::Request) }
    end
  end
end
