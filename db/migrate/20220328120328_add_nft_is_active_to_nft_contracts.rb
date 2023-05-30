class AddNftIsActiveToNftContracts < ActiveRecord::Migration[6.1]
  def change
    add_column :nft_contracts, :is_active, :boolean, default: true
  end
end
