class UsersController < ApplicationController
  before_action :authenticate_user, except: [:show, :artist]
  before_action :is_approved, except: [:show, :artist]
  before_action :set_user, only: [:show, :follow, :unfollow, :like, :unlike, :report, :load_tabs, :collection_hide]

  def my_items
    @user = current_user
    @is_owner = true
    build_data
    @user_address_url = @user.address
    render "show"
  end

  def show
    build_data
    @is_owner = current_user == @user
  end

  def build_data
    @reportees = @user.reports.pluck(:created_by_id)
    @page_no = params[:page_no] || 1
    @tab = params[:tab]
    @data = ApplicationController.helpers.get_collections(@user, @tab, params[:filters]).paginate(page: @page_no, per_page: (params[:tab].eql?("activity") ? 20 : 12))
    @created_count = ApplicationController.helpers.get_collections(@user, "created", params[:filters]).count
    @on_sale_count = ApplicationController.helpers.get_collections(@user, "", params[:filters]).count
    @collectibles_count = ApplicationController.helpers.get_collections(@user, "collectibles", params[:filters]).count
    @my_collections_count = ApplicationController.helpers.get_collections(@user, "my_collections", params[:filters]).count
    @followers_count = @user.followers.count
    @followees_count = @user.followees.count
    @liked = @user.likes.joins(:collection).order(created_at: :desc)
  end

  def collection_hide
    build_data
    return unless current_user.is_admin?
    if params[:collection_id].present?
      collection = Collection.unscoped.find(params[:collection_id])
      collection.update(is_active: params[:is_active].eql?('show'))
    end
    redirect_to collection_path(collection.address)
  end

  def edit
    @attachment = current_user.attachment
    @banner = current_user.banner
    @user_address_url = current_user.address
  end

  def artist
    @user = User.find_by(artist_url: params[:username]) || User.find_by(address: params[:username])
    if @user.present?
      @is_owner = current_user == @user
      build_data
      @user_address_url = @user.address
      render "show"
    else
      redirect_to root_path
    end
  end

  def update
    current_user.assign_attributes(user_params)
    if current_user.valid?
      current_user.save
      unless browser.device.mobile? || browser.device.tablet?
        current_user.attachment.attach(data: params[:attachemnt_data]) if params[:attachemnt_data].present?
        current_user.banner.attach(data: params[:attachemnt_data_banner]) if params[:attachemnt_data_banner].present?
      end
    else
      @error = [current_user.errors.full_messages].compact
    end
    redirect_to edit_user_path(current_user)
  end

  def follow
    Follow.find_or_create_by({follower_id: current_user.id, followee_id: @user.id})
    redirect_to user_path(@user.address), notice: 'Following successful'
  end

  def unfollow
    follow = Follow.where({follower_id: current_user.id, followee_id: @user.id}).first
    follow.destroy if follow.present?
    redirect_to user_path(@user.address), notice: 'Unfollowed successful'
  end

  def like
    render json: {success: @user.like_collection(params)}
  end

  def unlike
    render json: {success:  @user.unlike_collection(params)}
  end

  def report
    reportees = @user.reports.pluck(:created_by_id)
    unless reportees.include?(current_user.id)
      @user.reports.create({message: params[:message], created_by: current_user})
    end
    redirect_to user_path(@user.address)
  end

  def following
  end

  def create_contract
    @nft_contract = current_user.nft_contracts.create(name: params[:name], symbol: params[:symbol], address: params[:contract_address], contract_type: params[:contract_type], description: params[:description], txn_hash: params[:txn_hash])
    if browser.device.mobile? || browser.device.tablet?
      @nft_contract.attachment.attach(params[:file]) if params[:file].present?
      @nft_contract.cover.attach(params[:cover]) if params[:cover].present?
    else
      @nft_contract.attachment.attach(data: params[:file]) if params[:file].present?
      @nft_contract.cover.attach(data: params[:cover]) if params[:cover].present?
    end
    collection = current_user.collections.unscoped.where(address: params[:collection_id]).first
    collection.update_attribute('nft_contract_id', @nft_contract.id) if collection
  end

  def load_tabs
    @page_no = params[:page_no] || 1
    @tab = params[:tab]
    @data = @user.get_collections(@tab, params[:filters], @page_no)
    @followers_count = @user.followers.count
    @followees_count = @user.followees.count
    @liked = @user.likes
  end

  def remove_nft_contract
    nft = current_user.nft_contracts.find(params[:nft_id])
    nft.update(is_active: false)
    nft.collections.unscoped.where(nft_contract_id: nft.id).update_all(is_active: false)
    redirect_to user_path(id: current_user.address, tab: "my_collections", page_no: params[:page_no])
  end

  private

  def user_params
    params.require(:user).permit(:name, :bio, :attachment, :twitter_link, :personal_url, :banner)
  end

  def set_user
    @user = User.find_by(address: params[:id])
    redirect_to root_path unless @user.present?
  end
end
