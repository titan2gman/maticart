class AddTxnHashToCollection < ActiveRecord::Migration[6.1]
  def change
    add_column :collections, :txn_hash, :string
    add_column :collections, :fee_refunded, :boolean, default: false
    add_column :collections, :fee_refunded_txn_hash, :string
  end
end
