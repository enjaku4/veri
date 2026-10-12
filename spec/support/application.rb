class DummyApplication < Rails::Application
  config.eager_load = true
  config.autoload_paths << File.expand_path("models", __dir__)
  config.autoload_paths << File.expand_path("controllers", __dir__)
  config.cache_store = :null_store
end

DummyApplication.initialize!

DummyApplication.routes.draw do
  root to: "dummy#home"

  resources :dummy, only: [:index]
  resources :api, only: [:create]
end
