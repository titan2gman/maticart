class Admin::BaseController < ApplicationController
  layout 'admin'
  skip_before_action :authenticate_user
  skip_before_action :is_approved
  before_action :check_user

  def after_sign_in_path_for
    admin_dashboard_path
  end

  def check_user
    if current_user && current_user.is_admin? && current_user.admin_user.present?
      sign_in(:admin_admin_user, current_user.admin_user)
    else
      authenticate_admin_admin_user!
    end
  end
end
