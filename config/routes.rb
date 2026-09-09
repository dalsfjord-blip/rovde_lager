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
  resources :storage_items, only: [:index, :create] do
    collection do
      post :add_item
    end
    member do
      delete :remove_item
    end
  end

  # Del 2: Kundeinformasjon
  resource :customer_info, only: [:index, :update]
  get "contract", to: "customer_info#index", as: :contract

  # Del 3: Betaling
  resource :payment, only: [:index, :create]
  
  # Kvittering
  resource :receipt, only: [:show] do
    post :email, on: :member
  end

  # Root path
  root "storage_items#index"
end
