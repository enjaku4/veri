require "digest/sha2"

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
      user_model = Veri::Configuration.user_model
      primary_key = user_model.primary_key
      @current_user ||= current_session ? user_model.find_by(primary_key => current_session.authenticatable_id) : nil
    end

    def current_session
      token = cookies.encrypted["#{auth_cookie_prefix}_token"]
      @current_session ||= token ? Session.find_by(hashed_token: Digest::SHA256.hexdigest(token), **resolved_tenant) : nil
    end

    # TODO: tests for all changed methods where applicable
    def log_in(authenticatable)
      processed_authenticatable = Veri::Inputs::Authenticatable.new(
        authenticatable,
        message: "Expected an instance of #{Veri::Configuration.user_model_name}, got `#{authenticatable.inspect}`"
      ).process

      return false if processed_authenticatable.locked?

      token = Veri::Session.establish(processed_authenticatable, request, **resolved_tenant)

      cookies.encrypted.permanent["#{auth_cookie_prefix}_token"] = { value: token, httponly: true }
      true
    end

    def log_out
      current_session&.terminate
      cookies.delete("#{auth_cookie_prefix}_token")
    end

    def logged_in?
      current_user.present?
    end

    def return_path
      cookies.signed["#{auth_cookie_prefix}_return_path"]
    end

    def shapeshifter?
      !!current_session&.shapeshifted?
    end

    private

    def with_authentication
      if logged_in? && current_session.active?
        if current_user.locked?
          log_out
          when_unauthenticated
        else
          current_session.update_info(request)
        end

        return
      end

      log_out

      cookies.signed["#{auth_cookie_prefix}_return_path"] = { value: request.fullpath, expires: 15.minutes.from_now } if request.get? && request.format.html?

      when_unauthenticated
    end

    def when_unauthenticated
      request.format.html? ? redirect_back(fallback_location: root_path) : head(:unauthorized)
    end

    def current_tenant = nil

    def resolved_tenant
      @resolved_tenant ||= Veri::Inputs::Tenant.new(
        current_tenant,
        error: Veri::InvalidTenantError,
        message: "Expected a string, an ActiveRecord model instance, or nil, got `#{current_tenant.inspect}`"
      ).resolve
    end

    def auth_cookie_prefix
      @auth_cookie_prefix ||= "auth_#{Digest::SHA2.hexdigest(Marshal.dump(resolved_tenant))[0..7]}"
    end
  end
end
