module Veri
  module Authentication
    extend ActiveSupport::Concern

    included do
      include ActionController::Cookies unless self < ActionController::Cookies

      helper_method(:current_user, :logged_in?, :shapeshifter?, :current_session) if respond_to?(:helper_method)
    end

    class_methods do
      def with_authentication(options = {})
        before_action :with_authentication, **options
      rescue ArgumentError => e
        raise Veri::InvalidArgumentError, e.message
      end

      def skip_authentication(options = {})
        skip_before_action :with_authentication, **options
      rescue ArgumentError => e
        raise Veri::InvalidArgumentError, e.message
      end
    end

    def current_user
      @current_user ||= current_session&.authenticatable
    end

    def current_session
      token = cookies.encrypted["veri_token"]

      @current_session ||= Session.find_active(token, resolved_tenant)
    end

    def log_in(authenticatable)
      processed_authenticatable = Veri::Inputs::Authenticatable.new(
        authenticatable,
        message: "Expected an instance of #{Veri::Configuration.user_model_name}, got `#{authenticatable.inspect}`"
      ).process

      return false if processed_authenticatable.locked?

      token = Veri::Session.establish(processed_authenticatable, request, resolved_tenant)

      cookies.encrypted.permanent["veri_token"] = { value: token, httponly: true }
      reset_memoization
      true
    end

    def log_out
      current_session&.terminate
      cookies.delete("veri_token")
      reset_memoization
    end

    def logged_in?
      current_user.present?
    end

    def return_path
      cookies.signed["veri_return_path"]
    end

    def shapeshifter?
      !!current_session&.shapeshifted?
    end

    private

    def with_authentication
      if logged_in? && !current_user.locked?
        current_session.update_info(request)
        return
      end

      log_out

      cookies.signed["veri_return_path"] = { value: request.fullpath, expires: 15.minutes.from_now } if request.get? && request.format.html?

      when_unauthenticated
    end

    def when_unauthenticated
      request.format.html? ? redirect_back_or_to(root_path) : head(:unauthorized)
    end

    def current_tenant = nil

    def resolved_tenant
      @resolved_tenant ||= Veri::Inputs::Tenant.new(
        current_tenant,
        error: Veri::InvalidTenantError,
        message: "Expected a string, an ActiveRecord model instance, or nil, got `#{current_tenant.inspect}`"
      ).resolve
    end

    def reset_memoization
      @current_user = @current_session = nil
    end
  end
end
