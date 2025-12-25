module Veri
  module Inputs
    class Duration < Veri::Inputs::Base
      private

      def processor = -> { @value.is_a?(ActiveSupport::Duration) ? @value : raise_error }
    end
  end
end
