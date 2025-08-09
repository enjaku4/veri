require "dry-types"

module Veri
  module Inputs
    extend self

    include Dry.Types()

    # TODO: separate classes per type, add Tenant type that would check that tenant is nil, string, or ActiveRecord instance
    # TODO: Tenant type must be able to resolve tenant, and transform it into { tenant_type:, tenant_id: } hash

    TYPES = {
      hashing_algorithm: -> { self::Strict::Symbol.enum(:argon2, :bcrypt, :scrypt) },
      duration: -> { self::Instance(ActiveSupport::Duration) },
      non_empty_string: -> { self::Strict::String.constrained(min_size: 1) },
      model: -> { self::Strict::Class.constructor { _1.try(:safe_constantize) || _1 }.constrained(lt: ActiveRecord::Base) },
      authenticatable: -> { self::Instance(Veri::Configuration.user_model) },
      request: -> { self::Instance(ActionDispatch::Request) }
    }.freeze

    def process(value, as:, optional: false, error: Veri::InvalidArgumentError, message: nil)
      checker = type_for(as)
      checker = checker.optional if optional

      checker[value]
    rescue Dry::Types::CoercionError => e
      raise error, message || e.message
    end

    private

    def type_for(name) = Veri::Inputs::TYPES.fetch(name).call
  end
end
