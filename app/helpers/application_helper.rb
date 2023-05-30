module ApplicationHelper
  def build_filter_path(activity_type, filters, current_filter, options={})
    new_filters = filters.clone || []
    final_filters = new_filters.include?(current_filter) ? new_filters.filter { |x| x != current_filter } : new_filters << current_filter
    if activity_type == "following"
      activities_path(activity_type: "following", filters: final_filters.uniq)
    elsif activity_type == "activity"
      activities_path(activity_type: "activity", filters: final_filters.uniq)
    elsif activity_type == "my_activity"
      if current_user&.address == options[:user_id]
        my_items_path(activity_type: "activity", filters: final_filters.uniq, tab: options[:tab], id: options[:user_id])
      else
        user_path(activity_type: "activity", filters: final_filters.uniq, tab: options[:tab], id: options[:user_id])
      end
    else
      activities_path(filters: final_filters.uniq)
    end
  end

  def get_activities(activity_type, user, filters)
    if activity_type == "following"
      user.following_activities(filters)
    elsif activity_type == "activity"
      if filters == 'my_collections'
        user.nft_contracts.includes(owner: { attachment_attachment: :blob })
      else
        user.self_activities(filters)
      end
    elsif activity_type == "blank"
      user.self_activities(["minted"])
    end
  end

  def get_actual_count(activity_type, user, filters)
    activities = get_activities(activity_type, user, filters)
    count = 0
    activities.map {|activity| count += 1 if check_dependencies((filters.eql?('minted') ? 'minted' : (filters.eql?('my_collections') ? 'my_collections' : activity.item_type)), activity) }
    count
  end

  def check_dependencies(filter, activity)
    case filter
    when "minted"
      (activity.event == 'create' || (activity.event == 'update' && Collection.is_valid_activity(activity) && (!activity.changeset["state"].present? || (activity.changeset["state"].present? && activity.changeset["state"] != ["pending", "approved"])))) unless activity.item.blank?
    when "Collection"
      (activity.event == 'create' || (activity.event == 'update' && Collection.is_valid_activity(activity) && (!activity.changeset["state"].present? || (activity.changeset["state"].present? && activity.changeset["state"] != ["pending", "approved"]))))
    when "Follow"
      activity.event == 'create'
    when "Like"
      (activity.event == "create" && activity.item.user.present? && activity.item.collection.present?) unless activity.item.blank?
    when "Bid"
      activity.item.user.present? && activity.item.collection.present? && (activity.event == 'create' || (activity.event == 'update' && activity.changeset.keys.include?("state") && ["executed", "expired"].include?(activity.changeset["state"].last)))
    else
      true
    end
  end

  def is_filter_active(filters, current_filter)
    filters = filters || []
    # 'active' if filters.include?(current_filter)
    'active' if filters.eql?(current_filter)
  end

  def selected_tab(current_user, nft)
    current_user.activity_custom_tabs.find_by(nft_id: nft.id)&.custom_tab
  end

  def amt_with_service_fee(value)
    eval(value) + service_fee_for_value(value)
  end

  def service_fee_for_value(amt)
    eval("#{amt} * #{service_fee} / 100").round(5) rescue 0
  end

  def toastr_flash(script = true)
    flash_messages = []
    flash.each do |type, message|
      message = message.join('<br/>') if message.is_a?(Array)
      type = 'success' if type == 'notice'
      type = 'error' if type == 'alert'
      toastr_flash = "toastr.#{type}(\"#{message}\", '', { closeButton: true, progressBar: true })"
      toastr_flash = "<script>#{toastr_flash}</script>" if script
      flash_messages << toastr_flash.html_safe if message
    end
    flash_messages.join("\n").html_safe
  end

  def custom_error_flash error, type = 'info', script = false
    message = error.is_a?(Array) ? error.join('<br/>') : error
    flash_messages = "toastr.#{type}(\"#{j(message)}\")"
    flash_messages = "<script type='text/javascript'>#{j(flash_messages)};</script>" if script
    flash_messages.html_safe
  end

  def collection_type_img collection
    collection.single? ? 'single_nft' : 'multiple_nft'
  end

  def current_url
    url_for :only_path => false
  end

  def collection_type contract_type='multiple'
    contract_type == 'multiple' ? 'ERC-1155' : 'ERC-721'
  end

  def boolean_str(value)
    value ? 'Yes' : 'No'
  end

  def get_month(type)
    case type
    when 'day'
      24.hours.ago
    when 'week'
      5.days.ago
    when 'month'
      1.month.ago
    when 'mid_year'
      6.months.ago
    else
      5.days.ago
    end
  end
end
