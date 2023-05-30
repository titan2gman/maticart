class CollectionsController < ApplicationController
  skip_before_action :authenticate_user, only: [:show]
  skip_before_action :is_approved, only: [:show]
  # before_action :set_collection, only: [:show, :bid, :execute_max_bid, :remove_from_sale, :execute_bid, :buy]
  before_action :set_collection, except: [:new, :create, :update_hash, :update_token_id, :sign_metadata_hash, :add_comment]

  skip_before_action :verify_authenticity_token


  def new
    @collection_type = params[:type]
  end

  def show
    @tab = params[:tab]
    @activities = PaperTrail::Version.where(item_type: "Collection", item_id: @collection.id).order("created_at desc")
    @max_bid = @collection.max_bid
    set_collection_gon
    @transactions = @collection.get_collections(false)
    @comments = @collection.comments
  end

  def create
    begin
      # ActiveRecord::Base.transaction do
        @collection = Collection.new(collection_params)
        @collection.state = :pending
        # ITS A RAND STRING FOR IDENTIFIYING THE COLLECTION. NOT CONTRACT ADDRESS
        @collection.address = Collection.generate_uniq_token
        @collection.creator_id = current_user.id
        @collection.owner_id = current_user.id
        @collection.royalty = 0 unless @collection.royalty.present?
        @collection.data = JSON.parse(collection_params[:data]) if collection_params[:data].present?
        @collection.owned_tokens = @collection.no_of_copies
        if @collection.valid?
          @collection.save
          @metadata_hash = Api::Pinata.new.upload(@collection)
          # PaperTrail.request(enabled: false) { @collection.approve! }
        else
          @errors = @collection.errors.full_messages
        end
      # end
    rescue Exception => e
      Rails.logger.warn "################## Exception while creating collection ##################"
      Rails.logger.warn "ERROR: #{e.message}, PARAMS: #{params.inspect}"
      Rails.logger.warn $!.backtrace[0..20].join("\n")
      @errors = e.message
    end
  end

  def bid
    begin
      @collection.place_bid(bid_params)
    rescue Exception => e
      Rails.logger.warn "################## Exception while creating BID ##################"
      Rails.logger.warn "ERROR: #{e.message}, PARAMS: #{params.inspect}"
      Rails.logger.warn $!.backtrace[0..20].join("\n")
      @errors = e.message
    end
  end

  def remove_from_sale
    if @collection.is_owner?(current_user)
      @collection.remove_from_sale
      @collection.cancel_bids
    end
    redirect_to collection_path(@collection.address)
  end

  def sell
    begin
      ActiveRecord::Base.transaction do
        @redirect_address = @collection.execute_bid(params[:address], params[:bid_id], params[:transaction_hash]) if @collection.is_owner?(current_user)
      end
    rescue Exception => e
      Rails.logger.warn "################## Exception while selling collection ##################"
      Rails.logger.warn "ERROR: #{e.message}, PARAMS: #{params.inspect}"
      Rails.logger.warn $!.backtrace[0..20].join("\n")
      @errors = e.message
    end
  end

  def buy
    begin
      ActiveRecord::Base.transaction do
        @redirect_address = @collection.direct_buy(current_user, params[:quantity].to_i, params[:transaction_hash])
      end
    rescue Exception => e
      Rails.logger.warn "################## Exception while buying collection ##################"
      Rails.logger.warn "ERROR: #{e.message}, PARAMS: #{params.inspect}"
      Rails.logger.warn $!.backtrace[0..20].join("\n")
      @errors = e.message
    end
  end

  def update_token_id
    # Make sure the collection belongs to the current_user
    collection = current_user.collections.unscoped.where(address: params[:collectionId]).take
    # collection should still be pending (minting just ended)
    return unless collection.pending?
    collection.approve! unless collection.instant_sale_price.present?
    collection.update(token: params[:tokenId])
    Notification.notify_mint_success(collection)
  end

  def update_hash
    # Make sure the collection belongs to the current_user
    collection = current_user.collections.unscoped.where(address: params[:collectionId]).take
    # collection should still be pending (minting just began)
    return unless collection.pending?
    # the refund job is registered once at the start of the minting transaction
    # if necessary, this job will wait for at most 10 minutes for calls to
    # 'update_token_id' and 'signed_fixed_price'
    if !collection.fee_refunded && collection.txn_hash.nil?
      ApplicationController.helpers.custom_error_flash('Minting Refund process running', 'error')
      RefundMintingFeeJob.perform_in(3.minutes, collection.id)
    end
    if !collection.nft_contract&.refund_fee && !collection.nft_contract&.txn_hash.nil? && !collection.nft_contract.shared?
      ApplicationController.helpers.custom_error_flash('Refund contract process running', 'error')
      RefundContractFeeJob.perform_in(3.minutes, collection.id)
    end
    # register the hash sent by the most recent call to update_hash
    # at this stage 2 calls are expected:
    # - hash at minting start
    # - hash at minting success if different
    if params[:txnHash].present?
      collection.update(txn_hash: params[:txnHash])
    end
  end

  def change_price
    @collection.assign_attributes(change_price_params)
    @collection.save
  end

  def burn
    if @collection.multiple?
      all_collections = Collection.where(nft_contract_id: @collection.nft_contract_id, token: @collection.token)
      #Using UPDATE_ALL to FORCE-skip cases where no_of_copies > owned_tokens for a brief moment 
      all_collections.update_all(:no_of_copies => @collection.no_of_copies - params[:supply].to_i)
      if @collection.owned_tokens == params[:supply].to_i #User has 2 actions, BURN ALL vs BURN some!
        @collection.burn! if @collection.may_burn?
      else
        @collection.update(:owned_tokens => @collection.owned_tokens - params[:supply].to_i)
      end 
    else   
      @collection.burn! if @collection.may_burn?
    end
  end

  def transfer_token
    new_owner = User.find_by_address(params[:user_id])
    if new_owner.present?
      @collection.hand_over_to_owner(new_owner.id)
    else
      @errors = [t("collections.show.invalid_user")]
    end
  end

  def sign_metadata_hash
    sign = if params[:contract_address].present?
      collection = current_user.collections.unscoped.where(address: params[:id]).first
      obj = Utils::Web3.new
      obj.sign_metadata_hash(params[:contract_address], collection.metadata_hash, current_user.address)
    else
      ""
    end
    render json: sign
  end

  def fetch_details
    render json: {data: @collection.fetch_details(params[:bid_id], params[:erc20_address])}
  end

  def add_comment
    collection = Collection.find_by(id: params[:id])
    comment = collection.comments.new(user_id: @current_user.id, description: params[:comment][:description])

    unless comment.save
      flash[:error] = comment.errors.full_messages
    end
    redirect_to collection_path(collection.address)
  end

  def fetch_transfer_user
    user = User.validate_user(params[:address])
    if @collection.owner.eql?(user)
      render json: {error: 'Impossible to transfer to the sender'}
    elsif user && user.is_approved? && user.is_active?
      render json: {address: user.address}
    else
      render json: {error: 'User not found or not activated yet. Please provide address of the user registered in the application'}
    end
  end

  def sign_fixed_price
    collection = current_user.collections.unscoped.where(address: params[:id]).take
    collection.approve! if collection.pending?
    collection.update(sign_instant_sale_price: params[:sign])
  end

  def owner_transfer
    collection = current_user.collections.where(address: params[:id]).take
    recipient_user = User.where(address: params[:recipient_address]).first
    if collection.multiple?
      collection.hand_over_to_owner(recipient_user.id, params[:transaction_hash], params[:supply].to_i)
    else 
      collection.hand_over_to_owner(recipient_user.id, params[:transaction_hash], collection.owned_tokens)
    end
  end
  private

  # Collection param from React  
  # def collection_params
  #   params.permit(:name, :description, :collection_address, :put_on_sale, :instant_sale_price, :unlock_on_purchase,
  #     :collection_category, :no_of_copies, :attachment)
  # end

  def collection_params
    params['collection']['category'] = params['collection']['category'].present? ? params['collection']['category'].split(",") : []
    params['collection']['nft_contract_id'] = NftContract.get_shared_id(params[:collection][:collection_type]) if params['chooseCollection'] == 'nft'
    params['collection']['nft_contract_id'] = NftContract.find_by_address(params['chooseOwnCollection'])&.id if params['chooseOwnCollection']!= 'new' && params['chooseCollection'] == 'create'
    params['collection']['erc20_token_id'] = Erc20Token.where(address: params[:collection][:currency]).first&.id if params[:collection][:currency].present?
    params.require(:collection).permit(:name, :description, :collection_address, :put_on_sale, :instant_sale_enabled, :instant_sale_price, :unlock_on_purchase,
                               :bid_id, :no_of_copies, :attachment, :cover, :data, :collection_type, :royalty, :nft_contract_id, :unlock_description,
                               :erc20_token_id, :country, category: [])
  end

  def change_price_params
    params[:collection][:put_on_sale] = false if params[:collection][:put_on_sale].nil?
    params[:collection][:unlock_on_purchase] = false if params[:collection][:unlock_on_purchase].nil?
    unless params[:collection][:instant_sale_enabled]
      params[:collection][:instant_sale_enabled] = false
      params[:collection][:instant_sale_price] = nil
    end
    params.require(:collection).permit(:put_on_sale, :instant_sale_enabled, :instant_sale_price, :unlock_on_purchase, :unlock_description, :erc20_token_id)
  end

  def bid_params
    params[:user_id] = current_user.id
    params.permit(:sign, :quantity, :user_id, details: {})
  end

  def set_collection
    @collection = Collection.unscoped.find_by(address: params[:id])
    redirect_to root_path unless @collection.present?
  end

  def set_gon
    gon.collection_data = @collection.gon_data
  end

  def set_collection_gon
    gon.collection_data = @collection.gon_data
  end
end
























