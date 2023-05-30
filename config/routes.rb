Rails.application.routes.draw do
  scope "(/:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    namespace :admin do
      devise_for :admin_users, controllers: {
        sessions: 'admin/admin_users/sessions',
      }
      resources :users do
        collection do
          get :reports
          get :make_admin
          get :multiple_collection_hide
        end

        member do
          get :collections
          post :collection_hide
          get :approve
          get :deny
          get :enable
          get :verify
          post :remove_custom_tab
          get :nft_contracts
          post :hide_contracts
        end
      end
      resources :categories
      resources :fees
      resources :featured_users, except: [:edit, :update]
      resources :featured_collections, except: [:edit, :update]
      resources :transactions, only: [:index]
      get 'setting', to: 'setting#recent_hours'
      post 'setting', to: 'setting#update_recent_hours'
      get 'dashboard', to: 'dashboard#index'
      root to: 'dashboard#index'
    end

    resources :users, except: [:index, :create, :destroy] do
      collection do
        get :following
        get :follow
        get :unfollow
        get :load_tabs
        post :like
        post :unlike
        post :bid
        post :report
        post :create_contract
        delete :remove_nft_contract
      end

      member do
        post :collection_hide
      end
    end

    resources :nft_contracts, only: [:show]

    resources :collections, only: [:new, :show, :create]  do
      member do
        get :remove_from_sale
        get :fetch_details
        get :fetch_transfer_user
        post :bid
        post :buy
        post :sell
        post :update_token_id
        post :update_hash
        post :change_price
        post :transfer_token
        post :sign_metadata_hash
        post :sign_fixed_price
        post :owner_transfer
        post :burn
        post :add_comment
      end
    end

    resources :sessions, only: [:create, :destroy] do
      collection do
        get :valid_user
      end
    end
    resources :likes, only: [:create, :update]
    resources :bids
    resources :fees

    ### CUSTOM ROUTES
    get 'dashboard', to: 'dashboard#index'
    get 'top_buy_sell', to: 'dashboard#top_buyers_and_sellers'
    get 'owncollections', to: 'dashboard#collectionitemlists'
    get 'collections_sort', to: 'dashboard#sorted_by_price_or_title'
    get 'my_items', to: 'users#my_items'
    get 'activities', to: 'activities#index'
    post 'create_custom_tab', to: 'activities#create_custom_tab'
    delete 'remove_custom_tab', to: 'activities#remove_custom_tab'
    post 'assign_tab_to_activity', to: 'activities#assign_tab_to_activity'
    # get 'load_more_activities', to: 'activities#load_more'
    get 'search', to: 'dashboard#search'
    get 'notifications', to: 'dashboard#notifications'
    get 'contract_abi', to: 'dashboard#contract_abi'
    get 'category_filter', to: 'dashboard#set_categories_by_filter'
    get 'gas_price', to: 'dashboard#gas_price'
    get 'all_notifications', to: 'dashboard#all_notifications'

    ### STATIC PAGES
    get 'about', to: 'static#about'
    get 'faq', to: 'static#faq'
    get 'terms_conditions', to: 'static#terms_conditions'
    get 'privacy', to: 'static#privacypolicy'

    ### ROOT PAGE
    root to: "dashboard#index"

    ### THIRD-PARTY ROUTES
    require 'sidekiq/web'
    authenticated do
      mount Sidekiq::Web => '/sidekiq'
    end
    get '/:username', to: 'users#artist', constraints: { username: /[^\/]+/ }
  end
end

