class AddQuantityToTransaction < ActiveRecord::Migration[6.1]
  def change
    add_column :transactions, :quantity, :integer, default: 0
  end
end
