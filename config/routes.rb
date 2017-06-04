Al::Application.routes.draw do

  root to: "new#index"
  get "/new", to: "new#index", as: :new
  get "/brexit", to: "boards#brexit", as: :brexit_board
  get "/boards/brexit" => redirect("/brexit")
  post '/results' => 'home#save_email'
  resources :statements, path: "s" do
    collection do
      post 'create_and_vote'
    end
    member do
      get 'occupations'
      get 'educated_at'
    end
  end
  get "/contact" => "static_pages#contact"
  post "/contact" => "static_pages#contact_send_email"
  resources :follows, only: [:create, :destroy]
  resources :agreement_comments, only: :create
  resources :comments, only: :create
  resources :votes, only: :create
  resources :reason_categories, except: :show
  resources :professions, except: :show
  resources :reasons, only: [:edit, :update]
  resources :occupations, only: [:index, :show]
  resources :schools, only: [:index, :show]
  get "/search", to: 'searches#new', as: :new_search
  post "/search", to: 'searches#create', as: :search
  post '/vote', to: 'new#vote', as: :vote
  get '/entrepreneurs', to: 'static_pages#advice_for_entrepreneurs'
  post '/save_email' => 'individuals#save_email'
  post '/statements/quick' => 'statements#quick_create'
  resources :individuals, only: [:edit, :update, :destroy, :create], path: "" do
    member do
      get :activation
    end
  end
  get 'signup', to: 'individuals#new', as: :signup
  match '/add_supporter' => 'agreements#add_supporter', via: [:get, :post]

  get '/contact' => 'static_pages#contact'
  get '/join' => 'static_pages#join'
  post '/emails' => 'static_pages#send_email'
  get '/about' => 'static_pages#about'
  get '/faq' => 'static_pages#faq'

  match "/auth/twitter/callback" => 'sessions#create_with_twitter', via: [:get, :post]
  get "/login" => "sessions#new", as: :login
  get "/signout" => "sessions#destroy", as: :signout
  resources :reset_password, only: [:new, :create, :edit, :update]
  resources :sessions, only: :create
  resources :agreements, path: "a", only: [:show, :destroy, :update] do
    member do
      post 'upvote'
    end
  end
  get '/test' => 'static_pages#polar'

  get "/auth/failure" => redirect("/")
  post "/touch/:id" => 'agreements#touch', as: :touch

  post "/email" => 'static_pages#email'
  get "/terms" => "static_pages#terms", as: :terms
  get "/privacy" => "static_pages#privacy", as: :privacy
  get '/:id' => 'individuals#show', :as => :profile
end
