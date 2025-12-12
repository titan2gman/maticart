# Admin User
CHAIN_ID = Rails.env.development? ? 80001 : 137
AdminUser.find_or_create_by(email: "maticart@admin.com")
  .update(password: "8325f2f96921", first_name: "Admin", last_name: "User", password_confirmation: "8325f2f96921")

Fee.find_or_create_by(fee_type: 'Buyer') do |fee|
  fee.update(per_mile: '0')
end
Fee.find_or_create_by(fee_type: 'Seller') do |fee|
  fee.update(per_mile: '0')
end
Fee.find_or_create_by(fee_type: 'MaxRefundMint') do |fee|
  fee.update(per_mile: '0.05')
end
Fee.find_or_create_by(fee_type: 'MaxRefundBuyAsset') do |fee|
  fee.update(per_mile: '0.02')
end

["Art", "Animation", "Games", "Music", "Videos", "Memes", "Metaverses"].each { |c| Category.find_or_create_by(name: c) }

#Creating ERC20 Token List
if Rails.env.production?
  Erc20Token.find_or_create_by(chain_id: CHAIN_ID, symbol: 'WMATIC' )
    .update(address: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270', name: 'Wrapped Matic', decimals: 18)
else
  Erc20Token.find_or_create_by(chain_id: CHAIN_ID, symbol: 'WMATIC' )
    .update(address: '0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889', name: 'Wrapped Matic', decimals: 18)
end

### CREATING SHARED NFT CONTRACT ADDRESSES
if Rails.env.production?
  NftContract.find_or_create_by(contract_type: 'nft721',  is_shared: true, name: 'NFT', symbol: 'Shared', address: '0xA0a81A526484b9499ce308a59ef71A4693D00Ebc')
  NftContract.find_or_create_by(contract_type: 'nft1155', is_shared: true, name: 'NFT', symbol: 'Shared', address: '0x5Bc9c90bE23AF74dB084934c683d80f722E074d9')
  NftContract.find_or_create_by(contract_type: 'nft1155', is_shared: true, name: 'NFT', symbol: 'Shared', address: '0xCdF4c172e7Df3962fC32689C6c285A9824D5239b')
else
  NftContract.find_or_create_by(contract_type: 'nft721',  is_shared: true, name: 'NFT', symbol: 'Shared', address: '0x3f38265AFb1e103ddAB55BC7e5Fb9fA735a75eFc')
  NftContract.find_or_create_by(contract_type: 'nft1155', is_shared: true, name: 'NFT', symbol: 'Shared', address: '0x81d94b5EbB654c5Fb74eB6c46CC901c1eb6EbBdA')
  NftContract.find_or_create_by(contract_type: 'nft1155', is_shared: true, name: 'NFT', symbol: 'Shared', address: '0x39e0E574BDD02fdf4B7f227C177895e9dA34c83E')
end
