module Veri
  module Authentication
    extend ActiveSupport::Concern

    included do
      include ActionController::Cookies unless self < ActionController::Cookies

      helper_method(:current_user, :logged_in?, :shapeshifter?) if respond_to?(:helper_method)
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
      @current_user ||= current_session&.identity
    end

    def current_session
      token = cookies.encrypted[:veri_token]
      @current_session ||= token ? Session.find_by(hashed_token: Digest::SHA256.hexdigest(token)) : nil
    end

    def log_in(authenticatable)
      token = Veri::Session.establish(Veri::Inputs.process(authenticatable, as: :authenticatable), request)
      cookies.encrypted.permanent[:veri_token] = { value: token, httponly: true }
    end

    def log_out
      current_session&.terminate
      cookies.delete(:veri_token)
    end

    def logged_in?
      current_user.present?
    end

    def return_path
      cookies.signed[:veri_return_path]
    end

    def shapeshifter?
      !!current_session&.shapeshifted?
    end

    private

    def with_authentication
      current_session.update_info(request) and return if logged_in? && current_session.active?

      current_session&.terminate

      cookies.signed[:veri_return_path] = { value: request.fullpath, expires: 15.minutes.from_now } if request.get? && request.format.html?

      when_unauthenticated
    end

    def when_unauthenticated
      request.format.html? ? redirect_back(fallback_location: root_path) : head(:unauthorized)
    end
  end
end
