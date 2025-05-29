class DummyApplication < Rails::Application
  config.eager_load = true
  config.cache_store = :null_store
end

DummyApplication.initialize!

DummyApplication.routes.draw do
  root to: "dummy#home"

  resources :dummy, only: [:index]
  resources :api, only: [:create]
end
