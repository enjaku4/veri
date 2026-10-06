module Veri
  module Inputs
    class Base
      def initialize(value, optional: false, error: nil, message: nil)
        @value = value
        @optional = optional
        @error = error
        @message = message
      end

      def process
        return @value if @value.nil? && @optional

        processor.call
      end

      private

      def processor
        raise NotImplementedError
      end

      def default_error = Veri::InvalidArgumentError
      def default_message = nil

      def raise_error
        raise @error || default_error, @message || default_message
      end
    end
  end
end
