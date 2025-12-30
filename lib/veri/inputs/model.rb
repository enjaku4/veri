module Veri
  module Inputs
    class Model < Veri::Inputs::Base
      private

      def processor
        -> {
          model = @value.try(:safe_constantize) || @value
          raise_error unless model.is_a?(Class) && model < ActiveRecord::Base
          model
        }
      end
    end
  end
end
