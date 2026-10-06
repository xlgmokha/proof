Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  post "/session/logout" => "sessions#destroy", as: :logout
  post "/session/new" => "sessions#new"
  post '/oauth/token', to: 'oauth/tokens#create'
  resource :mfa, only: [:new, :create]
  resource :metadata, only: [:show]
  resource :session, only: [:new, :show, :create, :destroy]
  resources :registrations, only: [:new, :create]
  resource :response, only: [:show]
  namespace :my do
    resource :dashboard, only: [:show]
    resource :mfa, only: [:show, :new, :edit, :create, :destroy] do
      member do
        post :test
      end
    end
    resources :audits, only: [:index]
    resources :clients, only: [:index, :new, :create]
    resources :sessions, only: [:index, :destroy]
  end
  namespace :oauth do
    resource :authorizations, only: [:show, :create]
    resource :me, only: [:show, :create]
    resources :clients, only: [:show, :create, :update, :destroy]
    resource :tokens, only: [:create] do
      post :introspect
      post :revoke
    end
  end
  namespace :scim do
    namespace :v2, defaults: { format: :scim } do
      post ".search", to: "search#index"

      # RFC 7644 defines the capitalized endpoints. The lowercase paths predate
      # them and are kept so existing integrations continue to work.
      patch 'Users/:id', to: 'users#patch'
      patch 'users/:id', to: 'users#patch', as: nil
      resources :users, path: 'Users', only: [:index, :show, :create, :update, :destroy]
      resources :users, path: 'users', only: [:index, :show, :create, :update, :destroy], as: :legacy_users

      patch 'Groups/:id', to: 'groups#patch'
      patch 'groups/:id', to: 'groups#patch', as: nil
      resources :groups, path: 'Groups', only: [:index, :show, :create, :update, :destroy]
      resources :groups, path: 'groups', only: [:index, :show, :create, :update, :destroy], as: :legacy_groups

      get :ResourceTypes, to: "resource_types#index"
      get 'ResourceTypes/:id', to: "resource_types#show"
      resources :resource_types, only: [:index, :show]

      get :Schemas, to: 'schemas#index'
      get 'Schemas/:id', to: "schemas#show", constraints: { id: /.+/ }
      resources :schemas, only: [:index, :show], constraints: { id: /.+/ }

      get :ServiceProviderConfig, to: "service_providers#show"

      get 'Me', to: 'mes#show'
      put 'Me', to: 'mes#update'
      patch 'Me', to: 'mes#patch'
      delete 'Me', to: 'mes#destroy'
      post 'Bulk', to: 'bulk#create'
    end
  end
  get "/.well-known/oauth-authorization-server", to: "oauth/metadata#show"
  get "/.well-known/oauth-protected-resource(/*path)", to: "oauth/resource_metadata#show", format: false
  get "/.well-known/jwks.json", to: "oauth/jwks#show", as: :jwks
  direct :documentation do
    root_url + 'doc'
  end
  root to: "sessions#new"
end
ActiveSupport::Notifications.instrument 'proof.routes_loaded'
