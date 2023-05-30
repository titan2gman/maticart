class CreateCustomTabs < ActiveRecord::Migration[6.1]
  def change
    create_table :custom_tabs do |t|
      t.integer :user_id
      t.string :tab_name

      t.timestamps
    end
  end
end
