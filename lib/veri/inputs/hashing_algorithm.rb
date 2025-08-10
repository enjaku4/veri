module Veri
  module Inputs
    class HashingAlgorithm < Veri::Inputs::Base
      private

      def type = -> { self.class::Strict::Symbol.enum(:argon2, :bcrypt, :scrypt) }
    end
  end
end
