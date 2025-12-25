module Veri
  module Inputs
    class HashingAlgorithm < Veri::Inputs::Base
      HASHING_ALGORITHMS = [:argon2, :bcrypt, :pbkdf2, :scrypt].freeze
      private_constant :HASHING_ALGORITHMS

      private

      def processor = -> { HASHING_ALGORITHMS.include?(@value) ? @value : raise_error }
    end
  end
end
