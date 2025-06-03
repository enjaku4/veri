require "dry-types"

module Veri
  module Inputs
    extend self

    include Dry.Types()

    TYPES = {
      hashing_algorithm: -> { self::Strict::Symbol.enum(:argon2, :bcrypt, :scrypt) },
      duration: -> { self::Instance(ActiveSupport::Duration) },
      string: -> { self::Strict::String },
      model: -> { self::Strict::Class.constructor { _1.try(:safe_constantize) || _1 }.constrained(lt: ActiveRecord::Base) },
      authenticatable: -> { self::Instance(Veri::Configuration.user_model) },
      request: -> { self::Instance(ActionDispatch::Request) }
    }.freeze

    def process(value, as:, optional: false, error: Veri::InvalidArgumentError)
      checker = type_for(as)
      checker = checker.optional if optional

      checker[value]
    rescue Dry::Types::CoercionError => e
      raise error, e.message
    end

    private

    def type_for(name) = Veri::Inputs::TYPES.fetch(name).call
  end
end
