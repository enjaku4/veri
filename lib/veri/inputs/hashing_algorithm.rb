module Veri
  module Inputs
    class HashingAlgorithm < Veri::Inputs::Base
      private

      def processor = -> { Veri::Configuration::HASHERS.key?(@value) ? @value : raise_error }
    end
  end
end
