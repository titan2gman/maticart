class AddDiscardColumnToVersions < ActiveRecord::Migration[6.1]
  def change
    add_column :versions, :discard, :boolean, default: false
  end
end
