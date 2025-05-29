require "action_controller"
require "action_view"

class ApplicationController < ActionController::Base
  include Veri::Authentication

  with_authentication
end

class DummyController < ApplicationController
  def index = head :ok
end

class ApiController < ActionController::API
  include Veri::Authentication

  with_authentication

  def create = head :created
end
