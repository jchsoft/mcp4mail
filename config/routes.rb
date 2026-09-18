Rails.application.routes.draw do
  # MCP endpoint (hitch-rails); must precede the engine mount
  match "/mcp", to: "mcp#handle", via: :all
  # OAuth 2.1 (/oauth/*) and discovery (/.well-known/*)
  mount Hitch::Engine => "/"

  resource :session
  resource :registration, only: %i[ new create ]
  resources :mail_accounts, only: %i[ index new create destroy ] do
    get :activity, on: :member
  end
  get "connect-ai", to: "connect_ai#show", as: :connect_ai
  get "attachment-downloads/:token", to: "attachment_downloads#show", as: :attachment_download
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"
end
