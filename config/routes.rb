Rails.application.routes.draw do
  get "/health", to: "health#show"

  namespace :api do
    namespace :v1 do
      resources :clients, only: %i[index show create] do
        get :overview, to: "client_overviews#show"
        resources :financial_goals, only: %i[index show create update] do
          resources :goal_contributions, only: %i[index create]
        end
        resources :service_requests, only: %i[index show create update]
      end
    end
  end
end
