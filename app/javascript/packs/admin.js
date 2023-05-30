require ("packs/ethereum/web3.js")
require('packs/formatter.js');
global.BigNumber = require('bignumber.js');

$(document).on('click', '#fee_submit', function () {
  console.log($('select#fee_type').val());
  $("div.loading-gif.displayInMiddle").show();
  if($('select#fee_type').val() === 'Buyer'){
    updateBuyerServiceFee($('input#fee_per_mile').val())
  }
  else if($('select#fee_type').val() === 'Seller'){
    updateSellerServiceFee($('input#fee_per_mile').val())
  }
  else if($('select#fee_type').val() === 'Platform'){
    $("form#fee_form").submit();
    $("div.loading-gif.displayInMiddle").hide();
  }
  else if ($('select#fee_type').val() === 'MaxRefundBuyAsset') {
    $("form#fee_form").submit();
    $("div.loading-gif.displayInMiddle").hide();
  }
  else if ($('select#fee_type').val() === 'MaxRefundMint') {
    $("form#fee_form").submit();
    $("div.loading-gif.displayInMiddle").hide();
  }
  else if ($('select#fee_type').val() === 'MaxRefundOwnerCollectionFee') {
    $("form#fee_form").submit();
    $("div.loading-gif.displayInMiddle").hide();
  }
  else{
    toastr.error('Please select the fee type.');
    $("div.loading-gif.displayInMiddle").hide();
  }
});



    
