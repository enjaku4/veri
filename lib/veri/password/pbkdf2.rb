require "openssl"
require "base64"

module Veri
  module Password
    module Pbkdf2
      module_function

      SALT_BYTES = 16
      ITERATIONS = 200_000
      HASH_BYTES = 32
      DIGEST = "sha256"

      def create(password)
        salt = SecureRandom.random_bytes(SALT_BYTES)
        hash = OpenSSL::KDF.pbkdf2_hmac(password, salt:, iterations: ITERATIONS, length: HASH_BYTES, hash: DIGEST)

        Base64.strict_encode64(salt + hash)
      end

      def verify(password, hashed_password)
        data = Base64.decode64(hashed_password)
        salt, expected_hash = data[0, SALT_BYTES], data[SALT_BYTES..]
        hash = OpenSSL::KDF.pbkdf2_hmac(password, salt:, iterations: ITERATIONS, length: HASH_BYTES, hash: DIGEST)

        OpenSSL.fixed_length_secure_compare(hash, expected_hash)
      end
    end
  end
end
