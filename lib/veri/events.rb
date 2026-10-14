module Veri
  module Events
    module_function

    def enabled?
      Veri::Configuration.events_enabled
    end

    def validate_actor(actor)
      raise Veri::InvalidArgumentError, "Actor is required when events are enabled" if enabled? && actor.nil?
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
