class RefundMintingFeeJob
  include Sidekiq::Worker
  sidekiq_options queue: 'high'

  def perform(collection_id)
    collection = Collection.unscoped.find_by(id: collection_id)
    return unless collection
    waiting = collection.created_at > (Time.now - 10.minutes)
    raise "waiting for call to 'update_token_id'" if waiting && collection.pending? && collection.token.nil?
    raise "waiting for call to 'sign_fixed_price'" if waiting && collection.pending? && collection.instant_sale_enabled && collection.sign_instant_sale_price.nil?

    begin
      if !collection.fee_refunded && collection.txn_hash.present?
        cap = Fee.MaxRefundMint.last&.refund_fee_cap
        txn_data = Utils::Web3.new.getRefundData(collection.txn_hash, cap)
        # analyze transaction log data
        tokenId = nil
        metadataHash = nil
        transferFrom = nil
        txn_data[:logs].each do |log|
          #Transfer(address,address,uint256)
          if log['topics'].first.casecmp?('0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef')
            transferFrom = log['topics'][1]
          end
          # TransferSingle(address,address,address,uint256,uint256)
          if log['topics'].first.casecmp?('0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62')
            transferFrom = log['topics'][2]
          end
          # URI(string,uint256)
          if log['topics'].first.casecmp?('0x6bb7ff708619ba0610cba295a58592e0451dee2622938c8755667688daf3529b')
            tokenId = log['topics'].last.to_i(16)
            metadataHash = [log['data'][2+2*64, log['data'][2+64,64].to_i(16)*2]].pack('H*')
          end
        end

        # check that the transaction seem correct
        raise "tx has a wrong 'from' address" unless collection.creator.address.casecmp?(txn_data[:toAddress])
        raise "tx is not a mint transaction" unless transferFrom.casecmp?('0x'+'00'*32)
        raise "tx mint metadata mismatch" unless collection.metadata_hash.casecmp?(metadataHash)
        raise "tx tokenId mismatch" unless collection.token.nil? || (collection.token.to_i == tokenId)

        # remove instant sale for stalled tokens where 'sign_fixed_price' was never called
        if collection.pending? && collection.instant_sale_enabled && collection.sign_instant_sale_price.nil?
          collection.update({instant_sale_enabled: false, instant_sale_price: nil, sign_instant_sale_price: nil})
        end

        # try to garbage collect stalled transactions for which 'update_token_id' was never called
        if collection.pending? && collection.token.nil? && !tokenId.nil?
          collection.update({ token: tokenId })
          Notification.notify_mint_success(collection)
        end

        if collection.pending? && collection.token.present?
          collection.approve!
        end

        if txn_data[:refundFee] == "0x0"
          refund_txn = nil
        else
          gas_price = Api::Gasprice.gas_price
          maxFeePerGas = (gas_price['fast']['maxFee'] * 10**9).round
          maxPriorityFeePerGas = (gas_price['fast']['maxPriorityFee'] * 10**9).round
          tx = {
            from: Settings.freeMinterPublicKey,
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
          #decimal_refund_fee = #("0x509E28AeCeD40F1f6874a2D2e8a142318b251642").to_i(16)/(1.0 * 10 ** 18)
          Notification.notify_refund_mint(collection, txn_data[:refund_fee_int].to_s.truncate(12))
        end
        collection.update(fee_refunded: true, fee_refunded_txn_hash: refund_txn)
      end
    end
  end
end
