Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API for vehicle lookup
  namespace :api do
    get "vehicle_lookup", to: "vehicle_lookups#show"
    get "brreg_lookups", to: "brreg_lookups#index"
    get "brreg_lookups/:organization_number", to: "brreg_lookups#show"
  end

  # Authentication
  get "login", to: "sessions#new", as: :login
  post "sessions", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout
  post "auth/vipps", to: "sessions#vipps_login", as: :vipps_login
  get "auth/vipps/callback", to: "sessions#vipps_callback", as: :vipps_callback
  get "auth/failure", to: "sessions#failure", as: :vipps_failure

  # Harbor rental
  get "hamneleige/login", to: "harbor_rentals#login", as: :harbor_rental_login
  resource :harbor_rental, path: "hamneleige", only: [ :show, :create ]

  # Main app routes
  resources :storage_items, only: [ :index, :create ] do
    collection do
      post :add_item
    end
    member do
      delete :remove_item
    end
  end

  # Del 2: Kundeinformasjon
  resource :customer_info, controller: "customer_info", only: [ :show, :update ]
  get "contract", to: "customer_info#show", as: :contract

  # Del 3: Betaling (OPPDATERT MED VIPPS CALLBACK)
  resource :payment, controller: "payment", only: [ :show, :create ] do
    get :vipps_callback, on: :member
    get :status, on: :member
    delete :dismiss, on: :member
    post :complete_demo, on: :member
  end

  # Webhook fra Vipps
  post "webhooks/vipps", to: "vipps_webhooks#receive"

  # Root path
  root "landing#show"
end
