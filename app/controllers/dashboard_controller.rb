class DashboardController < ApplicationController
  skip_before_action :authenticate_user
  skip_before_action :is_approved

  def index
    set_categories_by_filter
    unless request.xhr?
      @likes = current_user ? current_user.likes.pluck(:collection_id) : []
      @hot_bids = Collection.top_bids(30).with_attached_attachment
      @featured_users = FeaturedUser.limit(5).map(&:user)
      @featured_collections = FeaturedCollection.limit(5).map(&:collection).compact
      # @hot_collections = Collection.group(:owner).count

      # "Collections"
      @own_contract = NftContract
        .where
        .not(owner_id: nil)
        .order(created_at: :desc)
        .limit(100)
        .includes(attachment_attachment: { blob: :variant_records } )
        .includes(cover_attachment: { blob: :variant_records } )

      top_buyers_and_sellers
    end

    # "Recently Sold"
    sold_collection_ids = Transaction.all.order('created_at desc').pluck(:collection_id).uniq
    @sold_collections = Collection.unscope(:order)
      .where(id: sold_collection_ids)
      .order(Arel.sql("field(id, #{sold_collection_ids.join ','})"))
      .paginate(page: params[:page_no] || 1, per_page: 4)
      .includes(attachment_attachment: { blob: :variant_records })
      .includes(cover_attachment: { blob: :variant_records } )
      .includes(owner: { attachment_attachment: { blob: :variant_records } })

    most_traded = Collection.unscope(:order)
        .joins(:transactions)
        .where("transactions.created_at >= ?", ApplicationController.helpers.get_month(params[:sort_ago]))
        .group('transactions.collection_id')
        .order('COUNT(transactions.collection_id) DESC')
    @most_traded = most_traded
       .paginate(page: params[:page_no] || 1, per_page: 4)
       .includes(attachment_attachment: { blob: :variant_records })
       .includes(cover_attachment: { blob: :variant_records } )
       .includes(owner: { attachment_attachment: { blob: :variant_records } })
  end

  def set_categories_by_filter
    params[:page_no] ||= 1
    if params[:type].present?
      if params[:type].eql?('price')
        @category_collections = Collection.on_sale
          .unscoped.where("instant_sale_price is not null")
          .where(is_active: true,state: :approved)
          .order("instant_sale_price #{params[:sort_by]}")
          .filter_conditions(params[:category])
      elsif params[:type].eql?('type')
        category_collections_initials = Collection.multiple
                                          .on_sale.where("instant_sale_price is not null")
                                          .where('creator_id = owner_id')
                                          .where(is_active: true,state: :approved)
                                          .filter_conditions(params[:category])
        category_collections = category_collections_initials.sort_by { |collection| collection.sale_rate }
        category_collections = category_collections.reverse if params[:sort_by].eql?('desc')
        collection_ids = category_collections.pluck(:id)
        @category_collections = Collection.unscoped.multiple.where(id: collection_ids)
                                        .order(Arel.sql("field(id, #{collection_ids.join ','})"))
      else
        @category_collections = Collection.on_sale
          .unscoped
          .where("instant_sale_price is not null")
          .where(is_active: true,state: :approved)
          .filter_conditions(params[:category])
          .joins(:owner)
          .where(owner: {is_verified: true}).unscope(:order).order(created_at: :desc)
      end
      @category_collections = @category_collections
        .paginate(page: params[:page_no] || 1, per_page: 40)
        .includes(attachment_attachment: { blob: :variant_records } )
        .includes(cover_attachment: { blob: :variant_records } )
        .includes(owner: { attachment_attachment: { blob: :variant_records } })
    else
      @category_collections = params[:query].present? ? Collection.search("*#{params[:query].strip}*").records.on_sale : Collection.on_sale
      @category_collections = @category_collections.get_with_sort_option(params[:sort_by]).filter_conditions(params[:category])
      @category_collections = @category_collections
        .paginate(page: params[:page_no] || 1, per_page: 40)
        .includes(attachment_attachment: { blob: :variant_records } )
        .includes(cover_attachment: { blob: :variant_records } )
        .includes(owner: { attachment_attachment: { blob: :variant_records } })
    end
  end

  def top_buyers_and_sellers
    @top_sellers = User.top_seller(params[:days]).with_attached_attachment
    @top_buyers = User.top_buyer(params[:days]).with_attached_attachment
  end

  def search
    if params[:tab] =='users'
      @users = User.search("*#{params[:query]}*").records
    else
      params[:page_no] ||= 1
      if params[:type].present?
        if params[:type].eql?('price')
          collections = Collection.on_sale.unscoped
          collections = collections.search("*#{params[:query].strip}*", size:50).records.on_sale if params[:query].present?
          @collections = collections.unscope(:order).order("instant_sale_price #{params[:sort_by]}")
            .where("instant_sale_price is not null")
            .where(is_active: true, state: :approved)
            .filter_conditions(params[:category])
            .includes(attachment_attachment: { blob: :variant_records } )
            .includes(cover_attachment: { blob: :variant_records } )
            .includes(owner: { attachment_attachment: { blob: :variant_records } })
        elsif params[:type].eql?('type')
          @collections = Collection
            .on_sale
            .unscoped
            .where("instant_sale_price is not null")
            .where(is_active: true, state: :approved)
            .order("name #{params[:sort_by]}")
            .filter_conditions(params[:category])
            .includes(attachment_attachment: { blob: :variant_records } )
            .includes(cover_attachment: { blob: :variant_records } )
            .includes(owner: { attachment_attachment: { blob: :variant_records } })
        else
          collections = Collection.on_sale.unscoped
          collections = collections.search("*#{params[:query].strip}*", size:50).records.on_sale if params[:query].present?
          @collections = collections
            .where("instant_sale_price is not null")
            .where(is_active: true, state: :approved)
            .filter_conditions(params[:category])
            .includes(attachment_attachment: { blob: :variant_records } )
            .includes(cover_attachment: { blob: :variant_records } )
            .includes(owner: { attachment_attachment: { blob: :variant_records } })
            .where(owner: {is_verified: true}).unscope(:order).order(created_at: :desc)
        end
        @collections = @collections
          .paginate(page: params[:page_no] || 1, per_page: 50)
          .includes(attachment_attachment: { blob: :variant_records } )
          .includes(cover_attachment: { blob: :variant_records } )
          .includes(owner: { attachment_attachment: { blob: :variant_records } })
      else
        @collections = params[:query].present? ? Collection.search("*#{params[:query].strip}*", size:50).records.on_sale : Collection.on_sale
        @collections= @collections
          .filter_conditions(params[:category])
          .paginate(page: params[:page_no] || 1, per_page: 50)
          .includes(attachment_attachment: { blob: :variant_records } )
          .includes(cover_attachment: { blob: :variant_records } )
          .includes(owner: { attachment_attachment: { blob: :variant_records } })
      end
    end
  end

  # def notifications
  #   notifications = Notification.unread(current_user)
  #   if notifications
  #     notifications_ids = notifications.pluck(:id)
  #     notifications.update_all(is_read: true)
  #     @notifications = Notification.where(id: notifications_ids)
  #   end
  # end

  def all_notifications
    page_no = params[:page_no] || 1
    notifications = Notification.unread(current_user)
    if notifications
      notifications_ids = notifications.pluck(:id)
      notifications.update_all(is_read: true)
      @notifications = Notification.where(to_user_id: current_user.id).paginate(page: page_no, per_page: 50)
    end
    # page_no = params[:page_no] || 1
    # @notifications = Notification.where(to_user_id: current_user.id).paginate(page: page_no, per_page: 10)
  end

  def contract_abi
    shared = ActiveModel::Type::Boolean.new.cast(params[:shared])
    abi = if params[:contract_address].present? && params[:type] == 'erc20'
            Utils::Abi.wmatic
          elsif params[:contract_address].present? && (params[:type] == 'trade')
            Utils::Abi.trade
          elsif(shared)
            if params[:type] == 'nft721'
              Utils::Abi.shared_nft721
            elsif params[:type] == 'nft1155'
              Utils::Abi.shared_nft1155
            end
          elsif(!shared)
            if params[:type] == 'nft721'
              Utils::Abi.nft721
            elsif params[:type] == 'nft1155'
              Utils::Abi.nft1155
            end
          else
            {}
          end
          
    render json: {compiled_contract_details: abi}
  end

  def gas_price
    gas_price = Api::Gasprice.gas_price
    render json: {gas_price: gas_price}
  end

  def collectionitemlists
   @own_contract = NftContract.where.not(owner_id: nil).paginate(page: params[:page], per_page: 20)
  end

  def sorted_by_price_or_title
    @sorted = true
    params[:sort_by] ||= 'asc'
    if params[:search].present?
      search
      render "search"
    else
      index
      render "index"
    end
  end
end
