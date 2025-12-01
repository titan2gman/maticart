class ActivitiesController < ApplicationController
  # skip_before_action :authenticate_user, only: :index
  skip_before_action :is_approved

  def index
    current_user.custom_tabs.find_or_create_by(tab_name: 'Discarded')
    @nft_filter = true if params[:activity_type] == "blank"
    cookies.permanent["#{current_user.address.last(5)}_thumbnail_type"] = params[:thumbnail_type] || cookies["#{current_user.address.last(5)}_thumbnail_type"] || 'mini_thumbnail'
    #@thumbnail_type = cookies.permanent["#{current_user.address.last(5)}_thumbnail_type"]
    @thumbnail_type = params[:thumbnail_type].eql?('thumbnail') ? 'thumbnail' : 'mini_thumbnail'
    
    load_activities
  end

  def load_activities
    @page_no = params[:page_no] || 1
    @activities = if current_user.present?
      ApplicationController.helpers.get_activities(params[:activity_type], current_user, params[:filters]).paginate(page: @page_no, per_page: 20)
    else
      filter = params[:filters] || []
      User.default_activities(filter, @page_no)
    end
  end

  def create_custom_tab
    custom_tab = current_user.custom_tabs.new(tab_name: params[:tab_name])
    if custom_tab.save
      redirect_to activities_path(activity_type: "blank"), notice: "NFT file successfully created."
    else
      redirect_to activities_path(activity_type: "blank"), alert: custom_tab.errors.full_messages.compact * ' and '
    end
  end

  def assign_tab_to_activity
    activity_tab = if params[:item_type] == 'nft'
      current_user.activity_custom_tabs.find_by(nft_id: params[:item_id])
    else
      current_user.activity_custom_tabs.find_by(follow_id: params[:item_id])
    end

    if params[:tab_id].present? && params[:tab_id] != 'show'
      if activity_tab.present?
        activity_tab.update(custom_tab_id: params[:tab_id])
      else
        activity_tab = ActivityCustomTab.new(custom_tab_id: params[:tab_id])
        if params[:item_type] == 'nft'
          activity_tab.nft_id = params[:item_id]
        else
          activity_tab.follow_id = params[:item_id]
        end
        activity_tab.save
      end
    else
      activity_tab&.destroy
    end  
  end

  def remove_custom_tab
    if params[:tab_id].present?
      current_user.custom_tabs.destroy(params[:tab_id])
    end
    redirect_to activities_path(activity_type: "activity", filters: 'minted')
  end
end

