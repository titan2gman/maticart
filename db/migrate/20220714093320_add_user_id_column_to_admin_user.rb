class AddUserIdColumnToAdminUser < ActiveRecord::Migration[6.1]
  def change
    add_column :admin_users, :user_id, :integer
  end
end
