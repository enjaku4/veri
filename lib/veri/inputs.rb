require "dry-types"

module Veri
  module Inputs
    extend self

    include Dry.Types()

    def process(value, as:, optional: false, error: Veri::InvalidArgumentError)
      checker = send(as)
      checker = checker.optional if optional

      checker[value]
    rescue Dry::Types::ConstraintError => e
      raise error, e.message
    end

    private

    def hashing_algorithm = self::Strict::Symbol.enum(:argon2, :bcrypt, :scrypt)
    def duration = self::Instance(ActiveSupport::Duration)
    def string = self::Strict::String
    def model = self::Strict::Class.constructor { _1.try(:safe_constantize) || _1 }.constrained(lt: ActiveRecord::Base)
    def authenticatable = self::Instance(Veri::Configuration.user_model)
    def request = self::Instance(ActionDispatch::Request)
  end
end
