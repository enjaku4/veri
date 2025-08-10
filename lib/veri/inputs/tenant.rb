module Veri
  module Inputs
    class Tenant < Base
      def resolve
        case tenant = process
        when nil
          { tenant_type: nil, tenant_id: nil }
        when String
          { tenant_type: tenant.to_s, tenant_id: nil }
        when ActiveRecord::Base
          raise_error unless tenant.persisted?
          { tenant_type: tenant.class.to_s, tenant_id: tenant.public_send(tenant.class.primary_key) }
        else
          tenant
        end
      end

      private

      def type
        -> {
          self.class::Strict::String.constrained(min_size: 1) |
            self.class::Instance(ActiveRecord::Base) |
            self.class::Hash.schema(
              tenant_type: self.class::Strict::String | self.class::Nil,
              tenant_id: self.class::Strict::String | self.class::Strict::Integer | self.class::Nil
            ) |
            self.class::Nil
        }
      end
    end
  end
end
