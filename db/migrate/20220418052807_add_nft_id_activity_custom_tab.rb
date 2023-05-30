class AddNftIdActivityCustomTab < ActiveRecord::Migration[6.1]
  def change
    add_column :activity_custom_tabs, :nft_id, :integer
    add_column :activity_custom_tabs, :follow_id, :integer
  end
end
