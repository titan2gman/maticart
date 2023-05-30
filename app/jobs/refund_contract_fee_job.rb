class RefundContractFeeJob
  include Sidekiq::Worker
  sidekiq_options queue: 'high'

  def perform(collection_id)
    collection = Collection.unscoped.find_by(id: collection_id)
    contract = collection.nft_contract
    return unless contract
    return if contract.refund_fee?
    return if contract.txn_hash.nil?

    begin
      cap = Fee.MaxRefundOwnerCollectionFee.last&.refund_fee_cap
      txn_data = Utils::Web3.new.getRefundData(contract.txn_hash, cap)

      if txn_data[:refundFee] == "0x0"
        refund_txn = nil
      else
        gas_price = Api::Gasprice.gas_price
        maxFeePerGas = (gas_price['fast']['maxFee'] * 10**9).round
        maxPriorityFeePerGas = (gas_price['fast']['maxPriorityFee'] * 10**9).round
        tx = {
          from: Settings.refundTransferPublicKey,
          to: txn_data[:toAddress],
          value: txn_data[:refundFee],
          gas: 21000,
          maxFeePerGas: maxFeePerGas,
          maxPriorityFeePerGas: maxPriorityFeePerGas
        }
        signed_txn = Utils::Web3.new.signTransaction(tx, Rails.application.credentials.refund_transfer_key)
        provider_host = URI.parse(Rails.application.credentials.ethereum_provider).host
        web3 = Web3::Eth::Rpc.new host: provider_host, port: 443, connect_options: { use_ssl: true }
        refund_txn = web3.eth.sendRawTransaction([signed_txn['rawTransaction']])
        Notification.notify_refund_contract(collection, txn_data[:refund_fee_int].to_s.truncate(12))
      end
      contract.update(refund_fee: true)
    end
  end
end
