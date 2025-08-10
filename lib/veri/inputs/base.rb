require "dry-types"

module Veri
  module Inputs
    class Base
      include Dry.Types()

      def initialize(value, optional: false, error: Veri::InvalidArgumentError, message: nil)
        @value = value
        @optional = optional
        @error = error
        @message = message
      end

      def process
        type_checker = @optional ? type.call.optional : type.call
        type_checker[@value]
      rescue Dry::Types::CoercionError
        raise_error
      end

      private

      def type
        raise NotImplementedError
      end

      def raise_error
        raise @error, @message
      end
    end
  end
end
