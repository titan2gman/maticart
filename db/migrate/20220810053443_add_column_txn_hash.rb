class AddColumnTxnHash < ActiveRecord::Migration[6.1]
  def change
  	add_column :nft_contracts, :txn_hash, :string, if_not_exists: true
    add_column :nft_contracts, :refund_fee, :boolean, if_not_exists: true
  end
end
