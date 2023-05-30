class AddSharedToNftContracts < ActiveRecord::Migration[6.1]
  def change
    add_column :nft_contracts, :is_shared, :boolean, default: false
    NftContract.connection.execute("UPDATE nft_contracts SET is_shared = TRUE WHERE symbol = 'Shared'")
  end
end
