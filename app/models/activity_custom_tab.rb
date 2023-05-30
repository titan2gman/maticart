class ActivityCustomTab < ApplicationRecord
  belongs_to :custom_tab
  belongs_to :nft, class_name: 'Collection', foreign_key: :nft_id, optional: true
end
