class ApiController < ActionController::API
  include Veri::Authentication

  with_authentication

  def create = head :created
end
