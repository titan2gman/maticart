class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  belongs_to :user
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_settings do |s|
    s.key :dashboard, defaults: {
      recent_hours: Rails.application.credentials.recent_hours,
      max_refund_minting_fee: 0.05
    }
  end

  def name
    name = "#{first_name} #{last_name}"
    name.present? ? name : "Admin"
  end
end
