Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  get "health", to: "health#show"

  namespace :api do
    get "session", to: "sessions#show"
    get "board", to: "boards#show"
    get "stats", to: "stats#show"
    post "pixels", to: "pixels#create"
    get "pixels/:x/:y", to: "pixels#show"
  end
end
