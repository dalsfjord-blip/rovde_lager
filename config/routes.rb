Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API for vehicle lookup
  namespace :api do
    get "vehicle_lookup", to: "vehicle_lookups#show"
  end

  # Authentication
  get "login", to: "sessions#new", as: :login
  post "sessions", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Main app routes
  resources :storage_items, only: [:index, :new, :create, :destroy] do
    collection do
      post :add_item
      delete :remove_item
    end
  end

  # Root path
  root "storage_items#index"
end
