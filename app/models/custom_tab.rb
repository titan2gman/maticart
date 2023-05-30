class CustomTab < ApplicationRecord
  belongs_to :user
  has_many :activity_custom_tabs, dependent: :destroy

  validates :tab_name,
            presence: true,
            uniqueness: { scope: :user_id }
end
