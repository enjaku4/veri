module Veri
  module Events
    module_function

    def enabled?
      Veri::Configuration.events_enabled
    end

    def publish(event)
      return unless enabled?

      payload = yield

      ActiveRecord.after_all_transactions_commit do
        ActiveSupport::Notifications.instrument("#{event}.veri", payload)
      end
    end
  end
end
