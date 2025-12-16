module Veri
  module Inputs
    class Tenant < Veri::Inputs::Base
      def resolve
        case tenant = process
        when nil
          { tenant_type: nil, tenant_id: nil }
        when String
          { tenant_type: tenant, tenant_id: nil }
        when ActiveRecord::Base
          raise_error unless tenant.persisted?
          { tenant_type: tenant.class.to_s, tenant_id: tenant.public_send(tenant.class.primary_key) }
        else
          tenant
        end
      end

      private

      def processor
        -> {
          return @value if @value.nil?
          return @value if @value.is_a?(String) && @value.present?
          return @value if @value.is_a?(ActiveRecord::Base)
          return @value if @value in { tenant_type: String | nil, tenant_id: String | Integer | nil }

          raise_error
        }
      end
    end
  end
end
