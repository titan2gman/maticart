class AddRefundedTransferFeeToTransaction < ActiveRecord::Migration[6.1]
  def change
    add_column :transactions, :refunded_transfer_fee, :boolean, default: false
    add_column :transactions, :refunded_transfer_fee_hash, :string
  end
end
