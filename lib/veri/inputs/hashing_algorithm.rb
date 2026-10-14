module Veri
  module Inputs
    class HashingAlgorithm < Veri::Inputs::Base
      private

      def validate_and_normalize = Veri::Configuration::HASHERS.key?(@value) ? @value : raise_error
    end
  end
end
