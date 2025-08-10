module Veri
  module Inputs
    class Authenticatable < Veri::Inputs::Base
      private

      def type = -> { self.class::Instance(Veri::Configuration.user_model) }
    end
  end
end
