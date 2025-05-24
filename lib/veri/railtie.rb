require "rails/railtie"

module Veri
  class Railtie < Rails::Railtie
    initializer "veri.to_prepare" do |app|
      app.config.to_prepare do
        user_model = Veri::Configuration.user_model
        user_model.include Veri::Authenticatable unless user_model < Veri::Authenticatable
      end
    end
  end
end
