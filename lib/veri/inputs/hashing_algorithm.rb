module Veri
  module Inputs
    class HashingAlgorithm < Veri::Inputs::Base
      private

      def processor = -> { [:argon2, :bcrypt, :pbkdf2, :scrypt].include?(@value) ? @value : raise_error }
    end
  end
end
