class AddUrlNameToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :artist_url, :string
  end
end
