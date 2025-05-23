module Veri
  module Authentication
    extend ActiveSupport::Concern

    included { helper_method(:current_user, :logged_in?) if respond_to?(:helper_method) }

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

    def current_user
      @current_user ||= current_session&.authenticatable
    end

    def login(authenticatable)
      raise Veri::InvalidArgumentError, "Expects an instance of #{Veri::Configuration.instance.user_model_name}" unless authenticatable.is_a?(Veri::Configuration.instance.user_model)

      token = Veri::Session.establish(authenticatable)

      cookies.encrypted.permanent[:veri_token] = { value: token, httponly: true }

      current_session.update_info(request)

      after_login
    end

    def logout
      current_session&.terminate
      after_logout
    end

    def logged_in?
      current_user.present?
    end

    def return_path
      session[:return_to]
    end

    private

    def with_authentication
      current_session.update_info(request) and return if logged_in? && !current_session.expired?

      current_session&.terminate

      session[:return_to] = request.fullpath

      when_unauthenticated
    end

    def current_session
      @current_session ||= Session.find_by(hashed_token: Digest::SHA256.hexdigest(cookies.encrypted[:veri_token]))
    end

    def when_unauthenticated
      request.format.html? ? redirect_back(fallback_location: root_path) : head(:unauthorized)
    end

    def after_login = nil
    def after_logout = nil
  end
end
