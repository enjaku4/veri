module Veri
  module Authentication
    extend ActiveSupport::Concern

    # TODO: no session

    included do
      helper_method(:current_user, :logged_in?) if respond_to?(:helper_method)
    end

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
      @current_user ||= User.find_by(id: session[:user_id])
    end

    def login(user)
      # TODO: create token if doesn't exist, store token in cookie, store digest in db
      session[:user_id] = user.id
      after_login
    end

    def logout
      # TODO: delete cookie
      session[:user_id] = nil
      after_logout
    end

    # TODO: logout everywhere - deletes the token digest from the db

    def logged_in?
      current_user.present?
    end

    def return_path
      session[:return_to]
    end

    private

    def with_authentication
      return if logged_in?

      # TODO: try relogin from cookie

      session[:return_to] = request.fullpath

      when_unauthenticated
    end

    def when_unauthenticated
      request.format.html? ? redirect_back(fallback_location: root_path) : head(:unauthorized)
    end

    def after_login = nil
    def after_logout = nil
  end
end
