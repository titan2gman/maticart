module Utils
  class Web3Schmoozer < Schmooze::Base
    dependencies Web3: 'web3'

    solidity_sha3_func =
      '
            function(contractAddress, userAddress, metadataHash, provider) {
                var web3 = new Web3(new Web3.providers.HttpProvider(provider));
                return web3.utils.soliditySha3(contractAddress, userAddress, metadataHash);
            }
        '

    sign_func =
      '
            function(msg, privateKey, provider) {
                var web3 = new Web3(new Web3.providers.HttpProvider(provider));
                return web3.eth.accounts.sign(msg, privateKey);
            }
        '

    signTransaction_func =
      '
            function(tx, privateKey, provider) {
                var web3 = new Web3(new Web3.providers.HttpProvider(provider));
                return web3.eth.accounts.signTransaction(tx, privateKey);
            }
        '

    encode_func =
      '
            function(jsonInterface, parameters, provider) {
                var web3 = new Web3(new Web3.providers.HttpProvider(provider));
                return web3.eth.abi.encodeFunctionCall(jsonInterface, parameters);
            }
        '

    recover_func =
      '
            function(msg, sign, provider) {
                var web3 = new Web3(new Web3.providers.HttpProvider(provider));
                return web3.eth.accounts.recover(msg, sign).toLowerCase();
            }
        '
    numberToHex_func =
      '
            function(value, provider) {
                var web3 = new Web3(new Web3.providers.HttpProvider(provider));
                return web3.utils.numberToHex(web3.utils.toWei(value.toString()));
            }
        '

    getTransactionData_func =
      '
            function(txnHash, provider) {
                var web3 = new Web3(new Web3.providers.HttpProvider(provider));
                return web3.eth.getTransactionReceipt(txnHash);
            }
        '

    method :solidity_sha3, solidity_sha3_func
    method :sign, sign_func
    method :signTransaction, signTransaction_func
    method :encodeFunctionCall, encode_func
    method :recover, recover_func
    method :numberToHex, numberToHex_func
    method :getTransactionData, getTransactionData_func
  end

  class Web3
    def initialize
      @web3_schmoozer = Web3Schmoozer.new(__dir__)
      @provider = Rails.application.credentials.ethereum_provider
    end

    def sign(msg)
      @web3_schmoozer.sign(msg, Rails.application.credentials.signer_private_key, @provider)
    end

    def signTransaction(tx, privateKey = Rails.application.credentials.signer_private_key)
      @web3_schmoozer.signTransaction(tx, privateKey, @provider)
    end

    def numberToHex(value)
      @web3_schmoozer.numberToHex(value, @provider)
    end

    def getRefundData(txnHash, cap = '0')
      receipt = @web3_schmoozer.getTransactionData(txnHash, @provider)
      raise "transaction data not yet available" if receipt.nil?
      raise "transaction is a failed transaction" if !receipt['status']
      effective_fee = (receipt['gasUsed'] * receipt['effectiveGasPrice'] * 10 ** -18).to_f
      max_refund_fee = cap.to_f
      refund_fee_int = effective_fee > max_refund_fee ? max_refund_fee : effective_fee
      refund_fee = numberToHex(refund_fee_int)
      {toAddress: receipt['from'], refundFee: refund_fee, refund_fee_int: refund_fee_int, logs: receipt['logs']}
    end

    def encodeFunctionCall(jsonInterface, parameters)
      @web3_schmoozer.encodeFunctionCall(jsonInterface, parameters, @provider)
    end

    def recover(msg, sign)
      @web3_schmoozer.recover(msg, sign, @provider)
    end

    def sign_metadata_hash(contract_address, metadata_hash, userAddress)
      hash = @web3_schmoozer.solidity_sha3(contract_address, userAddress, metadata_hash, @provider)
      sign(hash)
    end

    def valid_like?(signer, sign, contract_address, token_id)
      msg = I18n.t('sign.like', contract_address: contract_address, token_id: token_id)
      recover(msg, sign) == signer.downcase
    end

    def valid_put_on_sale_req?(signer, sign, contract_address, token_id)
      msg = I18n.t('sign.put_on_sale', contract_address: contract_address, token_id: token_id, owner_address: signer)
      recover(msg, sign) == signer.downcase
    end

    def valid_remove_from_sale_req?(signer, sign, contract_address, token_id)
      msg = I18n.t('sign.remove_from_sale', contract_address: contract_address, token_id: token_id, owner_address: signer)
      recover(msg, sign) == signer.downcase
    end

    def valid_start_action?(signer, sign, nft_contract_address, token_id, erc20_contract_address, min_price, start_time, end_time)
      msg = I18n.t('sign.start_action',
                   nft_contract_address: nft_contract_address,
                   token_id: token_id,
                   owner_address: signer,
                   erc20_contract_address: erc20_contract_address,
                   min_price: min_price,
                   start_time: start_time,
                   end_time: end_time)
      recover(msg, sign) == signer.downcase
    end
  end
end
