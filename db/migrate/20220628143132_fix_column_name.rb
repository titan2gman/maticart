class FixColumnName < ActiveRecord::Migration[6.1]
  def change
    rename_column :transactions, :tx_hash, :txn_hash
    rename_column :transactions, :refunded_transfer_fee, :fee_refunded
    rename_column :transactions, :refunded_transfer_fee_hash, :fee_refunded_txn_hash
  end
end
