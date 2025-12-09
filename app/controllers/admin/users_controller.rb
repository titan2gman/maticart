class Admin::UsersController < Admin::BaseController
  before_action :set_user, except: [:index, :new, :create]

  def index
    @users = if params[:name].present?
      users = User.where("name like ?", "%#{params[:name]}%")
      users = User.where(address: params[:name]) if users.blank?
      users.paginate(page: params[:page])
    else
      User.order(id: :desc).paginate(page: params[:page], per_page: 10)
    end
  end
  

  def new
    @user = User.new
  end

  def show
  end

  def edit
  end

  def create
  end

  def make_admin
    user = User.find_by(id: params[:user_id])
    if user.update(is_admin: params[:is_admin])
      if params[:is_admin].eql?('true')
        admin_user = AdminUser.create(email: "xyz" + params[:user_id] + "@gmail.com", password: 'password123xxxx', first_name: user.name, user_id: user.id ) 
      else
        user.admin_user.destroy
      end
      render json: {message: "User " + user.full_name + " is" + (params[:is_admin].eql?('true') ? " Admin" : " not Admin") + " now."}
    else
      render json: {error: user.errors.full_messages.compact * ' and '}
    end
  end

  def update
    @user.assign_attributes(user_params)
    if @user.valid?
      @user.save
      redirect_to admin_users_path
    else
      render action: 'edit'
    end
  end

  def destroy
    @user.update(is_active: false)
    @user.collections.update_all(is_active: false)
    respond_to do |format|
      format.html { redirect_to admin_users_path, notice: "User was successfully blocked." }
      format.json { head :no_content }
    end
  end

  def collections
    @collections = Collection.unscoped.where(state: :approved).order('created_at desc').where("creator_id=? or owner_id=?", @user.id, @user.id)
  end

  def collection_hide
    if params[:collection_id].present?
      collection = @user.collections.unscoped.find(params[:collection_id])
      collection.update(is_active: params[:is_active].eql?('show'))
    end
    redirect_to action: 'collections'
  end

  def multiple_collection_hide
    if params[:collection_ids]
      collections = @user.collections.unscoped.where(id: params[:collection_ids])
      collections.update(is_active: params[:is_active])
    end
    @collections = Collection.unscoped.where(state: :approved).order('created_at desc').where("creator_id=? or owner_id=?", @user.id, @user.id)
  end

  def nft_contracts
    @nft_contracts = NftContract.unscoped.where(owner_id: @user.id)
  end

  def hide_contracts
    @nft = @user.nft_contracts.unscoped.find(params[:contract_id])
    if params[:is_active].eql?('show')
      @nft.update(is_active: true)
      @nft.collections.update_all(is_active: true)
    elsif params[:is_active].eql?('hide')
      @nft.update(is_active: false)
      @nft.collections.update_all(is_active: false)
    end
    redirect_to action: 'nft_contracts'
  end

  def approve
    @user.update(is_approved: true)
    Notification.notify_profile_verified(@user)
    respond_to do |format|
      format.html { redirect_to admin_users_path, notice: "User was successfully approved." }
      format.json { head :no_content }
    end
  end

  def deny
    @user.update(is_approved: false)
    respond_to do |format|
      format.html { redirect_to admin_users_path, notice: "User was successfully denied." }
      format.json { head :no_content }
    end
  end

  def verify
    @user.update(is_verified: params[:verify])
    respond_to do |format|
      format.html { redirect_to admin_users_path, notice: "User was successfully verified." }
      format.json { head :no_content }
    end
  end

  def enable
    @user.update(is_active: true)
    Collection.unscoped.where(owner_id: @user.id).update_all(is_active: true)
    respond_to do |format|
      format.html { redirect_to admin_users_path, notice: "User was successfully enabled." }
      format.json { head :no_content }
    end
  end

  def reports
    @reports = ReportUser.order(created_at: :desc).paginate(page: params[:page], per_page: 10)
  end

  def remove_custom_tab
    if params[:tab_id].present?
      current_user.custom_tabs.destroy(params[:tab_id])
    end
    redirect_to activities_path(activity_type: "activity", filters: 'minted')
  end

  private

  def user_params
    params.require(:user).permit(:name, :bio, :twitter_link, :personal_url)
  end

  def set_user
    @user = User.find_by(id: params[:id])
  end
end
