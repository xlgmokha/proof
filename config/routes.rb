Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  post "/session/logout" => "sessions#destroy", as: :logout
  post "/session/new" => "sessions#new"
  post '/oauth/token', to: 'oauth/tokens#create'
  resource :mfa, only: [:new, :create]
  resource :metadata, only: [:show]
  resource :session, only: [:new, :create, :destroy]
  resources :registrations, only: [:new, :create]
  resource :response, only: [:show]
  namespace :my do
    resource :dashboard, only: [:show]
    resource :mfa, only: [:show, :new, :edit, :create, :destroy]
    resources :audits, only: [:index]
    resources :clients, only: [:index, :new, :create]
    resources :sessions, only: [:index]
  end
  namespace :oauth do
    resource :authorizations, only: [:show, :create]
    resource :me, only: [:show]
    resources :clients, only: [:create]
    resource :tokens, only: [:create] do
      post :introspect
      post :revoke
    end
  end
  namespace :scim do
    namespace :v2, defaults: { format: :scim } do
      post ".search", to: "search#index"

      get 'Groups/:id', to: 'groups#show'
      post :Groups, to: "groups#create"
      put 'Groups/:id', to: "groups#update"
      resources :groups, only: [:index]

      get :ResourceTypes, to: "resource_types#index"
      get 'ResourceTypes/:id', to: "resource_types#show"
      resources :resource_types, only: [:index, :show]

      get :Schemas, to: 'schemas#index'
      get 'Schemas/:id', to: "schemas#show"
      resources :schemas, only: [:index, :show]

      get :ServiceProviderConfig, to: "service_providers#show"

      get 'Users/:id', to: 'users#show'
      post :Users, to: "users#create"
      put 'Users/:id', to: "users#update"
      resources :users, only: [:index, :show, :create, :update, :destroy]

      match 'Me', to: lambda { |env| [501, {}, ['']] }, via: [:get, :post, :put, :patch, :delete]
      match 'Bulk', to: lambda { |env| [501, {}, ['']] }, via: [:post]
    end
  end
  get "/.well-known/oauth-authorization-server", to: "oauth/metadata#show"
  root to: "sessions#new"
end
