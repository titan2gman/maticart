class Admin::SettingController < Admin::BaseController
  def recent_hours
    @dashboard_setting = AdminUser.first.settings(:dashboard)
  end

  def update_recent_hours
    user = AdminUser.first
    user.settings(:dashboard).recent_hours = params[:recent_hours]
    user.save!
  end
end
