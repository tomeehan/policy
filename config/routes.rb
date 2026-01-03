# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
Rails.application.routes.draw do
  draw :jumpstart

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  namespace :onboarding do
    resources :policies, only: [:index, :create, :update, :destroy] do
      collection do
        post :complete
        get :progress
      end
    end
  end

  resources :policy_documents, path: "policies" do
    member do
      post :scan
    end
    resources :issues, only: [:index, :show, :update]
  end

  resources :issues, only: [:index]

  resources :suggested_changes, only: [] do
    member do
      post :apply
      post :dismiss
    end
  end

  authenticated :user do
    root to: "dashboard#show", as: :user_root
    # Alternate route to use if logged in users should still see public root
    # get "/dashboard", to: "dashboard#show", as: :user_root
  end

  # Public marketing homepage
  root to: "public#index"
end
