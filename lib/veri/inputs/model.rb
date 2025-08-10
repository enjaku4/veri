module Veri
  module Inputs
    class Model < Veri::Inputs::Base
      private

      def type = -> { self.class::Strict::Class.constructor { _1.try(:safe_constantize) }.constrained(lt: ActiveRecord::Base) }
    end
  end
end
