Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  resource :session, only: [:new, :create, :destroy]
  post "/session/logout" => "sessions#destroy", as: :logout
  post "/session/new" => "sessions#new"
  resource :metadata, only: [:show]
  resource :dashboard, only: [:show]
  resources :registrations, only: [:new, :create]
  resource :tfa, only: [:new, :edit, :create, :destroy]

  namespace :scim do
    namespace :v2, defaults: { format: :scim } do
      post ".search", to: "search#index"
      resources :users, only: [:index, :show, :create, :update, :destroy]
      get :ServiceProviderConfig, to: "service_providers#show"
      resources :groups, only: [:index]
      resources :resource_types, only: [:index]
      get :ResourceTypes, to: "resource_types#index"
      resources :schemas, only: [:index]

      match 'me', to: lambda { |env| [501, {}, ['']] }, via: [:get, :post, :put, :patch, :delete]
    end
  end
  root to: "sessions#new"
end
