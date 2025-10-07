require "openssl"
require "base64"
require "securerandom"

module Veri
  module Password
    module Pbkdf2
      module_function

      ITERATIONS = 210_000
      SALT_BYTES = 64
      HASH_BYTES = 64
      DIGEST = "sha512"

      def create(password)
        salt = SecureRandom.random_bytes(SALT_BYTES)
        hash = OpenSSL::KDF.pbkdf2_hmac(
          password,
          salt:,
          iterations: ITERATIONS,
          length: HASH_BYTES,
          hash: DIGEST
        )

        "#{DIGEST}$#{ITERATIONS}$#{HASH_BYTES}$#{Base64.strict_encode64(salt)}$#{Base64.strict_encode64(hash)}"
      end

      def verify(password, hashed_password)
        parts = hashed_password.split("$")
        digest, iterations, hash_bytes, encoded_salt, encoded_hash = parts[0], parts[1], parts[2], parts[3], parts[4]

        salt = Base64.strict_decode64(encoded_salt)
        hash = Base64.strict_decode64(encoded_hash)

        recalculated_hash = OpenSSL::KDF.pbkdf2_hmac(
          password,
          salt:,
          iterations: iterations.to_i,
          length: hash_bytes.to_i,
          hash: digest
        )

        OpenSSL.fixed_length_secure_compare(recalculated_hash, hash)
      end
    end
  end
end
