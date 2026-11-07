require "bcrypt"

module Veri
  module Password
    module BCrypt
      module_function

      def create(password)
        ::BCrypt::Password.create(password)
      end

      def verify(password, hashed_password)
        ::BCrypt::Password.new(hashed_password) == password
      end
    end
  end
end
