module Veri
  module Inputs
    class Authenticatable < Veri::Inputs::Base
      private

      def processor = -> { @value.is_a?(Veri::Configuration.user_model) ? @value : raise_error }
    end
  end
end
