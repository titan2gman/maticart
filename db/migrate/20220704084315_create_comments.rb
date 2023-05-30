class CreateComments < ActiveRecord::Migration[6.1]
  def change
    create_table :comments do |t|
      t.references :user, foreign_key: { to_table: :users }
      t.references :collection, foreign_key: { to_table: :collections }
      t.text :description

      t.timestamps
    end
  end
end
