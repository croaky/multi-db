Rails.application.routes.draw do
  root "things#index"
  resources :things, only: [:index, :new, :create]
end
