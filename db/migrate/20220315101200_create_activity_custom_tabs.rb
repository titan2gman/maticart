class CreateActivityCustomTabs < ActiveRecord::Migration[6.1]
  def change
    create_table :activity_custom_tabs do |t|
      t.integer :custom_tab_id
      t.integer :activity_id

      t.timestamps
    end
  end
end
