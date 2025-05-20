module Veri
  module Authenticatable
    extend ActiveSupport::Concern

    included do
      raise Veri::Error, "Veri::Authenticatable can only be included once" if defined?(@@included) && @@included != name

      @@included = name
    end

    # TODO
  end
end
