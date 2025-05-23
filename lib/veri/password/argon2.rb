require "argon2"

module Veri
  module Password
    module Argon2
      module_function

      def create(password)
        ::Argon2::Password.create(password)
      end

      def verify(password, hashed_password)
        ::Argon2::Password.verify_password(password, hashed_password)
      end
    end
  end
end
