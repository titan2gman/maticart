class AddTxHashToTransaction < ActiveRecord::Migration[6.1]
  def change
    add_column :transactions, :tx_hash, :string
  end
end
