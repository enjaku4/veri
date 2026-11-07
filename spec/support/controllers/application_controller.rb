class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication
end
