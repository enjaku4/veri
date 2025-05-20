module Veri
  module Authentication
    extend ActiveSupport::Concern

    class_methods do
      def with_authentication(options = {})
        before_action :with_authentication, **options
      rescue ArgumentError => e
        raise Veri::Error, e.message
      end

      def skip_authentication(options = {})
        skip_before_action :with_authentication, **options
      rescue ArgumentError => e
        raise Veri::Error, e.message
      end
    end

    private

    def with_authentication
      # TODO
    end

    def when_unauthenticated
      # TODO
    end
  end
end
