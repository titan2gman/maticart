import Web3 from 'web3';
import axios from "axios";
import detectEthereumProvider from '@metamask/detect-provider';
import WalletConnectProvider from '@walletconnect/web3-provider';

const tokenURIPrefix = gon.tokenURIPrefix;
const transferProxyContractAddress = gon.transferProxyContractAddress;
const wmaticAddress = gon.wmaticAddress;
const tradeContractAddress = gon.tradeContractAddress;
const chainId = gon.chainId;

const WALLET_TYPE_METAMASK = 'metamask';
const WALLET_TYPE_TRUST = 'trust';
const WALLET_TYPE_WALLETCONNECT = 'walletconnect';

let account;

function getWalletType() {
  const walletType = localStorage.getItem('walletType') || WALLET_TYPE_METAMASK;
  return walletType;
}

function setWalletType(walletType) {
  localStorage.setItem('walletType', walletType);
}


async function loadWeb3(walletType) {
  let provider;
  switch(walletType) {
    case WALLET_TYPE_METAMASK:
    case WALLET_TYPE_TRUST:
      provider = await detectEthereumProvider()
      if (provider) {
        window.web3 = new Web3(provider);
        window.web3.eth.transactionBlockTimeout = 10000;
        await provider.request({ method: 'eth_requestAccounts' })
        await provider.request({method: 'eth_accounts'})
        provider.on('accountsChanged', function (acc) {
          if (gon.session) {
            load(walletType, true);
          }
        })
      }
      break;
    case WALLET_TYPE_WALLETCONNECT:
      provider = new WalletConnectProvider({
        rpc: {
          137: 'https://polygon-rpc.com',
          80001: 'https://matic-mumbai.chainstacklabs.com',
        },
        chainId: gon.chainId
      });
      await provider.enable();
      provider.on("chainChanged", (chainId) => {
        if (gon.session) {
          load(walletType, true);
        }
      });
      provider.on('accountsChanged', function (acc) {
        if (gon.session) {
          load(walletType, true);
        }
      })
      window.web3 = new Web3(provider);
      break;
  }
  setWalletType(walletType);
}

async function getCurrentAccount() {
  const walletType = getWalletType();
  if (walletType === WALLET_TYPE_WALLETCONNECT) {
    return (await window.web3.eth.getAccounts())[0];
  }
  const provider = await detectEthereumProvider()
  return (await provider.request({ method: 'eth_accounts' }))[0]
}

async function checkNetwork() {
  const net2name = {
    "137": "Polygon/Matic Mainnet",
    "80001": "Polygon/Matic Mumbaï Testnet"
  }
  const netid = await web3.eth.getChainId();
  if (netid !== chainId) {
    throw new Error('Please make sure your wallet account is connected to ' + net2name[String(chainId)])
  }
}

async function createUserSession(address, balance, destroySession) {
  const config = {
    headers: {
      'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content'),
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    }
  }
  const resp = await axios.post(`/sessions`, {
    address: address,
    balance: balance,
    destroy_session: destroySession
  }, config)
    .then((response) => {
      return resp
    })
    .catch(err => {
    })
  return resp;
}

async function destroyUserSession(address) {
  const config = {
    data: {},
    headers: {
      'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content'),
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    }
  }
  const resp = axios.delete(`/sessions/${address}`, config)
    .then(response => response)
    .catch(err => {})
  return resp
}

function updateTokenId(tokenId, collectionId) {
  var request = $.ajax({
    url: `/collections/${collectionId}/update_token_id`,
    async: false,
    type: "POST",
    data: {tokenId: tokenId, collectionId: collectionId},
    dataType: "script"
  });
  request.done(function (msg) {
  });
  request.fail(function (jqXHR, textStatus) {
  });
}

function updateHash(txnHash, collectionId) {
  var request = $.ajax({
    url: `/collections/${collectionId}/update_hash`,
    async: true,
    type: "POST",
    data: { txnHash: txnHash, collectionId: collectionId },
    dataType: "script"
  });
  request.done(function (msg) {
  });
  request.fail(function (jqXHR, textStatus) {
  });
}

function createContract(formData) {
  var request = $.ajax({
    url: '/users/create_contract',
    async: false,
    type: "POST",
    data: formData,
    dataType: "script",
    processData: false,
    contentType: false,
    cache: false,
  });
  request.done(function (msg) {
  });
  request.fail(function (jqXHR, textStatus) {
  });
}

function updateCollectionBuy(collectionId, quantity, transactionHash) {
  var request = $.ajax({
    url: '/collections/' + collectionId + '/buy',
    type: 'POST',
    async: false,
    data: {quantity: quantity, transaction_hash: transactionHash},
    dataType: "script",
    success: function (respVal) {
    }
  });
}

function updateCollectionSell(collectionId, buyerAddress, bidId, transactionHash) {
  var request = $.ajax({
    url: '/collections/' + collectionId + '/sell',
    type: 'POST',
    async: false,
    data: {address: buyerAddress, bid_id: bidId, transaction_hash: transactionHash},
    dataType: "script",
    success: function (respVal) {
    }
  });
}

function updateOwnerTransfer(collectionId, recipientAddress, transactionHash, supply) {
  var request = $.ajax({
    url: '/collections/' + collectionId + '/owner_transfer',
    type: 'POST',
    async: false,
    data: {recipient_address: recipientAddress, transaction_hash: transactionHash, supply: supply},
    dataType: "script",
    success: function (respVal) {
    }
  });
}

function updateBurn(collectionId, transactionHash, supply) {
  var request = $.ajax({
    url: '/collections/' + collectionId + '/burn',
    type: 'POST',
    async: false,
    data: {transaction_hash: transactionHash, supply: supply},
    dataType: "script",
    success: function (respVal) {
    }
  });
}

async function isValidUser(address, token) {
  const config = {
    headers: {
      'X-CSRF-TOKEN': token,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    }
  }
  const resp = await axios.get(`/sessions/valid_user`, {params: {address: address, authenticity_token: token}}, config)
    .then((response) => {
      return response.data
    })
    .catch(err => {
    })
  return resp;
}

function placeBid(collectionId, sign, quantity, bidDetails) {
  var request = $.ajax({
    url: `/collections/${collectionId}/bid`,
    type: "POST",
    async: false,
    data: {sign: sign, quantity: quantity, details: bidDetails},
    dataType: "script"
  });
  request.done(function (msg) {
  });
  request.fail(function (jqXHR, textStatus) {
  });
}

function signMetadataHash(collectionId, contractAddress) {
  var sign;
  var request = $.ajax({
    url: `/collections/${collectionId}/sign_metadata_hash`,
    type: "POST",
    async: false,
    data: {contract_address: contractAddress},
    dataType: "json"
  });
  request.done(function (msg) {
    sign = msg['signature']
  });
  request.fail(function (jqXHR, textStatus) {
  });
  return sign;
}

function updateSignature(collectionId, sign) {
  var request = $.ajax({
    url: `/collections/${collectionId}/sign_fixed_price`,
    type: "POST",
    async: false,
    data: {sign: sign},
    dataType: "script"
  });
  request.done(function (msg) {
  });
  request.fail(function (jqXHR, textStatus) {
  });
}

window.getContractABIAndBytecode = function getContractABIAndBytecode(contractAddress, type, shared = true) {
  var res;
  var request = $.ajax({
    async: false,
    url: '/contract_abi',
    type: "GET",
    data: {contract_address: contractAddress, type: type, shared: shared},
    dataType: "json"
  });

  request.done(function (msg) {
    res = msg;
  });

  request.fail(function (jqXHR, textStatus) {
  });
  return res;
}

function splitSign(sign) {
  sign = sign.slice(2)
  var r = `0x${sign.slice(0, 64)}`
  var s = `0x${sign.slice(64, 128)}`
  var v = web3.utils.toDecimal(`0x${sign.slice(128, 130)}`)
  return [v, r, s]
}

window.getContract = async function getContract(contractAddress, type, shared = true) {
  var res = getContractABIAndBytecode(contractAddress, type, shared);
  var contractObj = await new window.web3.eth.Contract(res['compiled_contract_details']['abi'], contractAddress);
  return contractObj
}

window.createCollectible721 = async function createCollectible721(contractAddress, tokenURI, royaltyFee, collectionId, sharedCollection) {
  const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  var transactionHash = null;
  var ackHash = function(hash) {
    //console.log('ackHash called', hash);
    if (transactionHash == hash) return;
    transactionHash = hash;
    updateHash(transactionHash, collectionId);
  }
  await checkNetwork();
  var account = await getCurrentAccount();
  window.contract721 = await getContract(contractAddress, 'nft721', sharedCollection);
  var gasPrices = await gasPrice();
  var web3Call = null;
  var done = false;
  if (sharedCollection) {
    var sign = await signMetadataHash(collectionId, contractAddress);
    var signStruct = splitSign(sign);
    web3Call = window.contract721.methods.createCollectible(tokenURI, royaltyFee, signStruct)
  } else {
    web3Call = window.contract721.methods.createCollectible(tokenURI, royaltyFee)
  }
  web3Call.send({
    from: account,
    gas: 316883,
    gasPrice: String(gasPrices)
  })
  .once('transactionHash', async function(hash) {
    ackHash(hash);
    const txn = await web3.eth.getTransaction(hash);
    let blockNumber = await web3.eth.getBlockNumber();
    if (txn && txn.blockNumber != null) { return; }
    while (!done) {
      await delay(1000);
      //console.log('get block', blockNumber)
      var block = await web3.eth.getBlock(blockNumber, true)
      if (block) {
	for (let ti = 0; ti < block.transactions.length; ti++) {
	  const tx = block.transactions[ti];
          if (tx.from === txn.from && tx.nonce === txn.nonce) {
	    //console.log('replacement tx', tx.hash, tx.input === txn.input)
	    if (tx.input === txn.input) {
	      ackHash(tx.hash)
	      var receipt = await web3.eth.getTransactionReceipt(tx.hash)
	      if (receipt.status) {
	        var iEvent = window.contract721._jsonInterface.find(el => el.type == "event" && el.name == "Transfer")
	        var log = receipt.logs.find(el => el.topics[0] == iEvent.signature)
	        var params = web3.eth.abi.decodeLog(iEvent.inputs, log.data, log.topics.slice(1))
	        var tokenId = params.tokenId
	        //console.log('found tokenId', tokenId)
	        await updateTokenId(tokenId, collectionId)
	        window.collectionMintSuccess(collectionId)
	      } else {
	        window.collectionMintFailed("transaction failed")
	      }
	    } else {
	      window.collectionMintFailed("transaction was canceled or replaced")
	    }
	    done = true;
	    break;
	  }
        }
        blockNumber++;
      } else {
        await delay(1000);
      }
    }
  })
  .catch(function(err) {
    console.error(err);
    if (done) return;
    window.collectionMintFailed(err['message'])
    done = true;
  })
}

window.createCollectible1155 = async function createCollectible1155(contractAddress, supply, tokenURI, royaltyFee, collectionId, sharedCollection) {
  const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  var transactionHash = null;
  var ackHash = function(hash) {
    //console.log('ackHash called', hash);
    if (transactionHash == hash) return;
    transactionHash = hash;
    updateHash(transactionHash, collectionId);
  }
  await checkNetwork();
  var account = await getCurrentAccount();
  window.contract1155 = await getContract(contractAddress, 'nft1155', sharedCollection);
  var gasPrices = await gasPrice();
  var web3Call = null;
  var done = false;
  if (sharedCollection) {
    var sign = await signMetadataHash(collectionId, contractAddress);
    var signStruct = splitSign(sign);
    web3Call = window.contract1155.methods.mint(tokenURI, supply, royaltyFee, signStruct)
  } else {
    web3Call = window.contract1155.methods.mint(tokenURI, supply, royaltyFee)
  }
  web3Call.send({
    from: account,
    gas: 316883,
    gasPrice: String(gasPrices)
  })
  .once('transactionHash', async function(hash) {
    ackHash(hash);
    const txn = await web3.eth.getTransaction(hash);
    let blockNumber = await web3.eth.getBlockNumber();
    if (txn && txn.blockNumber != null) { return; }
    while (!done) {
      await delay(1000);
      //console.log('get block', blockNumber)
      var block = await web3.eth.getBlock(blockNumber, true)
      if (block) {
	for (let ti = 0; ti < block.transactions.length; ti++) {
	  const tx = block.transactions[ti];
          if (tx.from === txn.from && tx.nonce === txn.nonce) {
	    //console.log('replacement tx', tx.hash, tx.input === txn.input)
	    if (tx.input === txn.input) {
	      ackHash(tx.hash)
	      var receipt = await web3.eth.getTransactionReceipt(tx.hash)
	      if (receipt.status) {
	        var iEvent = window.contract1155._jsonInterface.find(el => el.type == "event" && el.name == "TransferSingle")
	        var log = receipt.logs.find(el => el.topics[0] == iEvent.signature)
	        var params = web3.eth.abi.decodeLog(iEvent.inputs, log.data, log.topics.slice(1))
	        var tokenId = params.id
	        //console.log('found tokenId', tokenId)
	        await updateTokenId(tokenId, collectionId)
	        window.collectionMintSuccess(collectionId)
	      } else {
	        window.collectionMintFailed("transaction failed")
	      }
	    } else {
	      window.collectionMintFailed("transaction was canceled or replaced")
	    }
	    done = true;
	    break;
	  }
        }
        blockNumber++;
      } else {
        await delay(1000);
      }
    }
  })
  .catch(function(err) {
    console.error(err);
    if (done) return;
    window.collectionMintFailed(err['message'])
    done = true;
  })

}

window.deployContract = async function deployContract(abi, bytecode, name, symbol, contractType, collectionId, attachment, description, cover) {
  const contractDeploy = new window.web3.eth.Contract(abi);
  var contractAddress;
  await checkNetwork();
  var account = await getCurrentAccount();
  var gasPrices = await gasPrice();
  contractDeploy.deploy({
    data: bytecode,
    arguments: [name, symbol, tokenURIPrefix]
  }).send({
    from: account,
    gas: 2803780,
    gasPrice: String(gasPrices) 
  }).on('confirmation', function(confirmationNumber, receipt) {
    var txn_hash = receipt["transactionHash"];
    $('#nft_contract_txn_hash').val(txn_hash);
    if (confirmationNumber == web3.eth.Contract.transactionConfirmationBlocks) {
      contractAddress = receipt.contractAddress;
      window.contractDeploySuccess(contractAddress, contractType)
    }
  }).then((deployment) => {
      contractAddress = deployment.options.address;
      $('#nft_contract_address').val(contractAddress);
      var txn_hash = $('#nft_contract_txn_hash').val();
      let formData = new FormData()
      formData.append('file', attachment)
      formData.append('name', name)
      formData.append('symbol', symbol)
      formData.append('contract_address', contractAddress)
      formData.append('txn_hash', txn_hash)
      formData.append('contract_type', contractType)
      formData.append('collection_id', collectionId)
      formData.append('description', description)
      formData.append('cover', cover)
      createContract(formData);
  }).catch((err) => {
    console.error(err);
    window.contractDeployFailed(err['message'])
  });
}

window.approveNFT = async function approveNFT(contractType, contractAddress, sharedCollection, sendBackTo = 'collection') {
  try {
    await checkNetwork();
    var account = await getCurrentAccount();
    window.contract = await getContract(contractAddress, contractType, sharedCollection);
    var isApproved = await window.contract.methods.isApprovedForAll(account, transferProxyContractAddress).call();
    if (!isApproved) {
      var gasPrices = await gasPrice();
      var receipt = await window.contract.methods.setApprovalForAll(transferProxyContractAddress, true).send({from: account, gas: 57791, gasPrice: String(gasPrices)});
    }
    if (sendBackTo == 'executeBid') {
      return window.approveBidSuccess()
    } else {
      return window.collectionApproveSuccess(contractType);
    }
  } catch (err) {
    console.error(err);
    if (sendBackTo == 'executeBid') {
      return window.approveBidFailed(err['message'])
    } else {
      return window.collectionApproveFailed(err['message'])
    }
  }
}

window.approveResaleNFT = async function approveResaleNFT(contractType, contractAddress, sharedCollection) {
  try {
    await checkNetwork();
    var account = await getCurrentAccount();
    window.contract = await getContract(contractAddress, contractType, sharedCollection);
    var isApproved = await window.contract.methods.isApprovedForAll(account, transferProxyContractAddress).call();
    if (!isApproved) {
      var gasPrices = await gasPrice();
      var receipt = await window.contract.methods.setApprovalForAll(transferProxyContractAddress, true).send({from: account, gas: 57791, gasPrice: String(gasPrices)});
    }
    return window.approveResaleSuccess(contractType);
  } catch (err) {
    console.error(err);
    return window.approveResaleFailed(err['message'])
  }
}

//TODO: OPTIMIZE
window.isApprovedNFT = async function isApprovedNFT(contractType, contractAddress) {
  try {
    await checkNetwork();
    var contract = await getContract(contractAddress, contractType);
    var account = await getCurrentAccount();
    var isApproved = await contract.methods.isApprovedForAll(account, transferProxyContractAddress).call();
    return isApproved;
  } catch (err) {
    console.error(err);
  }
}

window.burnNFT = async function burnNFT(contractType, contractAddress, tokenId, supply = 1, collectionId, sharedCollection) {
  try {
    await checkNetwork();
    var contract = await getContract(contractAddress, contractType, sharedCollection);
    var account = await getCurrentAccount();
    var gasPrices = await gasPrice();
    if (contractType == 'nft721') {
      var receipt = await contract.methods.burn(tokenId).send({
        from: account,
        gas: 123758,
        gasPrice: String(gasPrices)
      });
    } else if (contractType == 'nft1155') {
      var receipt = await contract.methods.burn(tokenId, supply).send({
        from: account,
        gas: 123758,
        gasPrice: String(gasPrices)
      });
    }
    await updateBurn(collectionId, receipt.transactionHash, supply)
    return window.burnSuccess(receipt.transactionHash);
  } catch (err) {
    console.error(err);
    return window.burnFailed(err['message'])
  }
}

window.directTransferNFT = async function directTransferNFT(contractType, contractAddress, recipientAddress, tokenId, supply = 1, shared, collectionId) {
  try {
    await checkNetwork();
    var contract = await getContract(contractAddress, contractType, shared);
    var account = await getCurrentAccount();
    var gasPrices = await gasPrice();
    if (contractType == 'nft721') {
      var receipt = await contract.methods.safeTransferFrom(account, recipientAddress, tokenId).send({
        from: account,
        gas: 125684,
        gasPrice: String(gasPrices)
      });
    } else if (contractType == 'nft1155') {
      // TODO: Analyse and use proper one in future
      var tempData = "0x6d6168616d000000000000000000000000000000000000000000000000000000"
      var receipt = await contract.methods.safeTransferFrom(account, recipientAddress, tokenId, supply, tempData).send({
        from: account,
        gas: 125684,
        gasPrice: String(gasPrices)
      });
    }
    await updateOwnerTransfer(collectionId, recipientAddress, receipt.transactionHash,supply)
    return window.directTransferSuccess(receipt.transactionHash, collectionId);
  } catch (err) {
    console.error(err);
    return window.directTransferFailed(err['message']);
  }
}

window.approveERC20 = async function approveERC20(contractAddress, contractType, amount, decimals = 18, sendBackTo = 'Bid') {
  try {
    await checkNetwork();
    amount = roundNumber(mulBy(amount, 10 ** decimals), 0);
    var compiledContractDetails = getContractABIAndBytecode(contractAddress, contractType, gon.collection_data['contract_shared']);
    var abi = compiledContractDetails['compiled_contract_details']['abi'];
    var contract = await new window.web3.eth.Contract(abi, contractAddress);
    var account = await getCurrentAccount();
    var gasPrices = await gasPrice();
    //var allowance = await contract.methods.allowance(account, transferProxyContractAddress).call();
    //var newAmount = roundNumber(plusNum(allowance, amount),0);
    var receipt = await contract.methods.approve(transferProxyContractAddress, amount).send({
      from: account,
      gas: 57791,
      gasPrice: String(gasPrices)
    });
    if (sendBackTo == 'Buy') {
      return window.buyApproveSuccess(receipt.transactionHash, contractAddress)
    } else {
      return window.bidApproveSuccess(receipt.transactionHash, contractAddress)
    }
  } catch (err) {
    console.error(err);
    if (sendBackTo == 'Buy') {
      return window.buyApproveFailed(err['message'])
    } else {
      return window.bidApproveFailed(err['message'])
    }
  }
}

window.approvedTokenBalance = async function approvedTokenBalance(contractAddress) {
  var contract = await getContract(contractAddress, 'erc20', false);
  var account = await getCurrentAccount();
  var balance = await contract.methods.allowance(account, transferProxyContractAddress).call();
  return balance;
}

window.convertWMATIC = async function convertWMATIC(amount, sendBackTo = 'Bid', decimals = 18) {
  try {
    await checkNetwork();
    amount = roundNumber(mulBy(amount, 10 ** decimals), 0);
    var compiledContractDetails = getContractABIAndBytecode(wmaticAddress, 'erc20');
    var abi = compiledContractDetails['compiled_contract_details']['abi'];
    
    var contract = await new window.web3.eth.Contract(abi, wmaticAddress);
    var account = await getCurrentAccount();
    var gasPrices = await gasPrice();
    var receipt = await contract.methods.deposit().send({from: account, value: amount,gas: 316883,gasPrice: String(gasPrices)});
    
    if (sendBackTo == 'Buy') {
      return window.buyConvertSuccess(receipt.transactionHash)
    } else {
      return window.bidConvertSuccess(receipt.transactionHash)
    }
  } catch (err) {
    console.error(err);
    if (sendBackTo == 'Buy') {
      return window.bidConvertFailed(err['message'])
    } else {
      return window.bidConvertFailed(err['message'])
    }

  }
}

window.updateBuyerServiceFee = async function updateBuyerServiceFee(buyerFeePermille) {
  try {
    await checkNetwork();
    var compiledContractDetails = getContractABIAndBytecode(tradeContractAddress, 'trade');
    var abi = compiledContractDetails['compiled_contract_details']['abi'];
    var contract = await new window.web3.eth.Contract(abi, tradeContractAddress);
    var account = await getCurrentAccount();
    var gasPrices = await gasPrice();
    var receipt = await contract.methods.setBuyerServiceFee(buyerFeePermille).send({from: account, gas: 316883,gasPrice: String(gasPrices)});
    if(String(receipt.status) === "true"){
      $("form#fee_form").submit();
      $("div.loading-gif.displayInMiddle").hide()
    }

  } catch (err) {
    console.error(err);
    $("div.loading-gif.displayInMiddle").hide()
    toastr.error(err.message)
    return false
  }
}

window.updateSellerServiceFee = async function updateSellerServiceFee(sellerFeePermille) {
  try {
    await checkNetwork();
    var compiledContractDetails = getContractABIAndBytecode(tradeContractAddress, 'trade');
    var abi = compiledContractDetails['compiled_contract_details']['abi'];
    var contract = await new window.web3.eth.Contract(abi, tradeContractAddress);
    var account = await getCurrentAccount();
    var gasPrices = await gasPrice();
    var receipt = await contract.methods.setSellerServiceFee(sellerFeePermille).send({from: account, gas: 316883,gasPrice: String(gasPrices)});
    if(String(receipt.status) === "true"){
      $("form#fee_form").submit();
      $("div.loading-gif.displayInMiddle").hide();
    }
  } catch (err) {
    console.error(err);
    $("div.loading-gif.displayInMiddle").hide()
    toastr.error(err.message)
    return false
  }
}

window.bidAsset = async function bidAsset(assetAddress, tokenId, qty = 1, amount, payingTokenAddress, decimals = 18, collectionId, bidPayAmt) {
  try {
    await checkNetwork();
    var amountInDec = roundNumber(mulBy(amount, 10 ** decimals), 0);
    var messageHash = window.web3.utils.soliditySha3(assetAddress, tokenId, payingTokenAddress, amountInDec, qty);
    var account = await getCurrentAccount();
    const signature = await window.web3.eth.personal.sign(messageHash, account);
    await placeBid(collectionId, signature, qty, {
      asset_address: assetAddress,
      token_id: tokenId,
      quantity: qty,
      amount: bidPayAmt,
      amount_with_fee: amount,
      payment_token_address: payingTokenAddress,
      payment_token_decimals: decimals
    })
    return window.bidSignSuccess(collectionId)
  } catch (err) {
    console.error(err);
    return window.bidSignFailed(err['message'])
  }
}

window.signMessage = async function signMessage(msg) {
  try {
    await checkNetwork();
    var account = await getCurrentAccount();
    var sign = await window.web3.eth.personal.sign(msg, account);
    return sign;
  } catch (err) {
    return ""
  }
}

window.signSellOrder = async function signSellOrder(amount, decimals, paymentAssetAddress, tokenId, assetAddress, collectionId, sendBackTo='') {
  try {
    await checkNetwork();
    amount = roundNumber(mulBy(amount, 10 ** decimals), 0);
    var messageHash = window.web3.utils.soliditySha3(assetAddress, tokenId, paymentAssetAddress, amount);
    var account = await getCurrentAccount();
    const fixedPriceSignature = await window.web3.eth.personal.sign(messageHash, account);
    await updateSignature(collectionId, fixedPriceSignature)
    if (sendBackTo == 'update') {
      return window.updateSignFixedSuccess(collectionId)
    } else {
      return window.bidSignFixedSuccess(collectionId)
    }
  } catch (err) {
    console.error(err);
    if(sendBackTo == 'update'){
      return window.updateSignFixedFailed(err['message'])
    }else{
      return window.bidSignFixedFailed(err['message'])
    }
  }
}

// buyingAssetType = 1 # 721
// buyingAssetType = 0 # 1155
window.buyAsset = async function buyAsset(assetOwner, buyingAssetType, buyingAssetAddress, tokenId, unitPrice, buyingAssetQty,
                                          paymentAmt, paymentAssetAddress, decimals, sellerSign, collectionId) {
  try {
    await checkNetwork();
    paymentAmt = roundNumber(mulBy(paymentAmt, 10 ** decimals), 0);
    unitPrice = roundNumber(mulBy(unitPrice, 10 ** decimals), 0);
    var compiledContractDetails = getContractABIAndBytecode(tradeContractAddress, 'trade');
    var abi = compiledContractDetails['compiled_contract_details']['abi'];
    var contract = await new window.web3.eth.Contract(abi, tradeContractAddress);
    var account = await getCurrentAccount();
    var orderStruct = [
      assetOwner,
      account,
      paymentAssetAddress,
      buyingAssetAddress,
      buyingAssetType,
      unitPrice,
      paymentAmt,
      tokenId,
      buyingAssetQty
    ]
    var gasPrices = await gasPrice();
    var receipt = await contract.methods.buyAsset(
      orderStruct,
      splitSign(sellerSign)
    ).send({from: account, gas: 316883, gasPrice: String(gasPrices), value: paymentAmt});
    await updateCollectionBuy(collectionId, buyingAssetQty, receipt.transactionHash)
    return window.buyPurchaseSuccess(collectionId)
  } catch (err) {
    console.error(err);
    return window.buyPurchaseFailed(err['message'])
  }
}

window.executeBid = async function executeBid(buyer, buyingAssetType, buyingAssetAddress, tokenId, paymentAmt, buyingAssetQty, paymentAssetAddress, decimals, buyerSign, collectionId, bidId) {
  try {
    await checkNetwork();
    paymentAmt = roundNumber(mulBy(paymentAmt, 10 ** decimals), 0);
    var unitPrice = 1;
    var compiledContractDetails = getContractABIAndBytecode(tradeContractAddress, 'trade');
    var abi = compiledContractDetails['compiled_contract_details']['abi'];
    var contract = await new window.web3.eth.Contract(abi, tradeContractAddress);
    var account = await getCurrentAccount();
    var orderStruct = [
      account,
      buyer,
      paymentAssetAddress,
      buyingAssetAddress,
      buyingAssetType,
      unitPrice,
      paymentAmt,
      tokenId,
      buyingAssetQty
    ]
    var gasPrices = await gasPrice();
    var receipt = await contract.methods.executeBid(
      orderStruct,
      splitSign(buyerSign)
    ).send({from: account, gas: 316883, gasPrice: String(gasPrices)});
    await updateCollectionSell(collectionId, buyer, bidId, receipt.transactionHash)
    return window.acceptBidSuccess(collectionId)
  } catch (err) {
    console.error(err);
    return window.acceptBidFailed(err['message'])
  }
}

window.ethBalance = async function ethBalance() {
  var account = await getCurrentAccount()
  var bal = await window.web3.eth.getBalance(account);
  var ethBal = roundNumber(web3.utils.fromWei(bal, 'ether'), 4);
  return ethBal;
}

window.updateEthBalance = async function updateEthBalance() {
  var ethBal = await window.ethBalance()
  $('.curBalance').html(ethBal + 'MATIC')
  $('.curEthBalance').text(ethBal)
}

window.tokenBalance = async function tokenBalance(contractAddress, decimals, address = null) {
  var abi = [{
    "constant": true,
    "inputs": [{"name": "_owner", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "balance", "type": "uint256"}],
    "payable": false,
    "type": "function"
  }]
  var contract = await new window.web3.eth.Contract(abi, contractAddress);
  var account = address || (await getCurrentAccount())
  var balance = await contract.methods.balanceOf(account).call();
  balance = roundNumber(divBy(balance, (10 ** decimals)), 4)
  return balance
}

window.tokenAllowance = async function tokenAllowance(contractAddress, decimals, address = null) {
  var abi = [{
    "constant":true,
    "inputs":[{"name":"","type":"address"},{"name":"","type":"address"}],
    "name":"allowance",
    "outputs":[{"name":"","type":"uint256"}],
    "payable":false,
    "stateMutability":"view",
    "type":"function"
  }]
  var contract = await new window.web3.eth.Contract(abi, contractAddress);
  var account = address || (await getCurrentAccount())
  var allowance = await contract.methods.allowance(account, transferProxyContractAddress).call();
  allowance = roundNumber(divBy(allowance, (10 ** decimals)), 4)
  return allowance
}


window.getNetworkType = async function getNetworkType() {
  var type = await web3.eth.net.getNetworkType();
  return type;
}

async function showTermsCondition(account, ethBal, networkType) {
  var account = account || await getCurrentAccount()
  $.magnificPopup.open({
    closeOnBgClick: false ,
		enableEscapeKey: false,
    items: {
      src: '#terms-and-condition'
    },
    type: 'inline'
  });
  $("#account").val(account)
  $("#eth_balance_tc").val(ethBal)
  $("#network_type").val(networkType)
}

async function load(walletType, shoulDestroySession = false) {
  await loadWeb3(walletType);
  var account = await getCurrentAccount()
  var networkType = await getNetworkType();
  var ethBal = await ethBalance();
  const isValidUserResp = await isValidUser(account, '');
  if (isValidUserResp.user_exists) {
    await createUserSession(account, ethBal, shoulDestroySession)
    if (shoulDestroySession) {
      window.location.href = '/'
    } else {
      return true;
    }
  } else {
    if (gon.session) {
      if (account) {
        await destroySession()
      }
      window.location.href = '/'
    } else {
      await showTermsCondition(account, ethBal, networkType)
      return false
    }
  }
}

window.disconnect = async function disconnect(address) {
  await destroySession()
  window.location.href = '/'
}

async function destroySession() {
  if (gon.session) {
    const walletType = getWalletType();
    if (walletType === WALLET_TYPE_WALLETCONNECT) {
      try {
        await window.web3.currentProvider.disconnect();
      } catch(e) {}
    }
    setWalletType(null)
    await destroyUserSession(account)
  }
}

window.connect = async function connect(walletType) {
  let provider
  switch(walletType) {
   case WALLET_TYPE_METAMASK:
     provider = await detectEthereumProvider()
     if (provider) {
       const status = await load(walletType);
       if (status) {
        window.location.href = '/'
      }
     } else {
       toastr.error('Please install the Metamask Extension in your browser. If it is already installed, you may need to allow it for this website by clicking on the extension icon');
     }
     break;
   case WALLET_TYPE_TRUST:
    provider = await detectEthereumProvider()
     if (provider) {
       const status = await load(walletType);
       if (status) {
        window.location.href = '/'
      }
     } else {
       toastr.error('Please use Trust Wallet . Then Dapps on the bottom of the home page . Then you are on a browser , type matic.art .');
     }
     break;
    case WALLET_TYPE_WALLETCONNECT:
      const status = await load(walletType);
       if (status) {
        window.location.href = '/'
      }
    break;
  }
}


window.proceedWithLoad = async function proceedWithLoad() {
  var account = $("#account").val()
  const ethBal = $("#eth_balance").text()
  const networkType = $("#network_type").val()
  if ($("#condition1").is(":checked") && $("#condition2").is(":checked")) {
    await createUserSession(account, ethBal, networkType)
    window.location.href = '/'
  } else {
    toastr.error('Please accept the conditions to proceed')
  }
}

window.loadUser = async function loadUser() {
  if (gon.session) {
    const walletType = getWalletType();
    await load(walletType);
  }
}

function gasPrice(){
  var init_gasPrice = '400000000000';
  try {
  var request = $.ajax({
    url: `/gas_price`,
    async: false,
    type: "GET"
  });
  request.done(function (msg) {
    if (msg['gas_price'] != '')
    {
      init_gasPrice = roundNumber(mulBy(msg['gas_price']['fast']['maxFee'], 10**9), 0)
    }
  });
  request.fail(function (jqXHR, textStatus) {
   });
} catch (err) {
  console.error(err);
}
 return toNum(init_gasPrice);
}
async function autoloadWeb3() {
  const provider = await detectEthereumProvider()
  if (!provider || !provider.isTrust) {
    $('.w_btn_trust a').attr({
	    'href': 'https://link.trustwallet.com/open_url?coin_id=966&url=https://' + window.location.hostname, 
	    'onclick': null
    })
  }

  if (gon.session) {
    const walletType = getWalletType();
    await loadWeb3(walletType);
  }
}

$(function () {
  autoloadWeb3();
});

