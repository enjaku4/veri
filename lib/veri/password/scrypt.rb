require "scrypt"

module Veri
  module Password
    module SCrypt
      module_function

      def create(password)
        ::SCrypt::Password.create(password)
      end

      def verify(password, hashed_password)
        ::SCrypt::Password.new(hashed_password) == password
      end
    end
  end
end
