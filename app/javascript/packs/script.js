import Web3 from "web3";
const chainId = gon.chainId;
$(document).ready(function() {
  if (window.web3 && window.web3.eth) {
    checkNetwork();
  }
  window.addEventListener("ajax:before", (e) => {
    if (e.target.id != 'load_more_link_most_trade' && e.target.id != 'load_more_link_sold' && e.target.id != 'load_more_link' && e.target.id != 'load_more_activity' && e.target.id != 'load_more_contract' && e.target.id != 'load_more_collections'){
      $(".loading-gif").show();
      $('body').css('overflow', 'hidden');
    }
  });
  window.addEventListener("ajax:complete", (e) => {
    $(".loading-gif").hide();
    $('body').css('overflow', 'auto');
  });
  $(document).on("change", ".localeChange", function() {
    window.location.href = "/?locale=" + $(".localeChange option:selected").val()
  })

  $(".activity_select").on('change', function(){
    $.ajax({
      type: "POST",
      url: "/assign_tab_to_activity",
      data: { tab_id: $(this).val(), item_id: $(this).data('item-id'), item_type: $(this).data('item-type')  },
      dataType: "script",
      success: function(result){
        toastr.success('Successfully Saved')
      }
    });
  })

  function readURL(input, previewId) {
    if (input.files && input.files[0]) {
      var reader = new FileReader();
      reader.onload = function(e) {
        $(previewId).css('background-image', 'url(' + e.target.result + ')');
        $(previewId).hide();
        $(previewId).fadeIn(650);
      }
      reader.readAsDataURL(input.files[0]);
    }
  }
  $("#imageUpload").change(function() {
    readURL(this, '#imagePreview');
  });
  $("#bannerUpload").change(function() {
    readURL(this, '#bannerPreview');
  });

  function readURLSingle(input, file, previewSection, imagePreview, closePreviewBtn, placeholder, fileId, chooseFile, coverImg) {
    var ftype = file.type;
    var fsize = file.size / 1024 / 1024; // in MBs
    if (fsize > 30) {
      return toastr.error('Invalid file size!. Must be less than 30MB');
    }
    var imgExt = ['image/png', 'image/jpeg', 'image/gif', 'image/webp'];
    var audExt = ['audio/mp3', 'audio/webm', 'audio/mpeg'];
    var vidExt = ['video/mp4', 'video/webm'];
    if (input.files && input.files[0]) {
      var reader = new FileReader();
      reader.onload = function(e) {
        if (imgExt.includes(ftype)) {
          previewSection.css('background-image', 'url(' + e.target.result + ')');
          previewSection.css({
            'width': '100%',
            'height': '260px',
            'border-radius': '15px',
            'background-size': 'cover',
            'background-repeat': 'no-repeat',
            'background-position': 'center',
            'margin-left': 'auto',
            'margin-right': 'auto',
          });
          previewSection.hide();
          previewSection.fadeIn(650);
          imagePreview.css('background-image', 'url(' + e.target.result + ')');
          imagePreview.css({
            'height': '225px'
          });
        } else if (coverImg) {
          return toastr.error('Invalid file type!');
        } else if (audExt.includes(ftype)) {
          $('.coverUpload').removeClass("hide");
          $('#file-2').prop('required', true);
          previewSection.hide();
          previewSection.fadeIn(650);
          imagePreview.html('<audio width="300" height="300" controls><source src="mov_bbb.mp4" id="audio_here"> </audio>');
          imagePreview.css({
            'height': '55px'
          });
          $('#audio_here')[0].src = URL.createObjectURL(input.files[0]);
          $('#audio_here').parent()[0].load();
        } else if (vidExt.includes(ftype)) {
          $('.coverUpload').removeClass("hide");
          $('#file-2').prop('required', true);
          previewSection.hide();
          previewSection.fadeIn(650);
          imagePreview.html('<video width="300" height="200" controls><source src="mov_bbb.mp4" id="video_here"> </video>');
          imagePreview.css({
            'height': '225px'
          });
          $('#video_here')[0].src = URL.createObjectURL(input.files[0]);
          $('#video_here').parent()[0].load();
        } else {
          return toastr.error('Invalid file type!');
        }
        imagePreview.css({
          'width': '300px',
          'background-size': 'cover',
          'background-repeat': 'no-repeat',
          'background-position': 'center',
          'margin-left': 'auto',
          'margin-right': 'auto',
          'border-radius': '15px'
        });
        closePreviewBtn.css('display', 'inline-block');
        placeholder.fadeOut(100);
        fileId.fadeOut(100);
        chooseFile.fadeOut(100);
        imagePreview.hide();
        imagePreview.fadeIn(650);
      }
      reader.readAsDataURL(input.files[0]);
    }
  }
  $("#file-1").change(function(e) {
    var file = e.currentTarget.files[0];
    var previewSection = $('#my-preview-section');
    var imagePreview = $('#imagePreviewRes');
    var closePreviewBtn = $('#close-preview-button');
    var placeholder = $('#placeholder');
    var fileId = $('#file-1');
    var chooseFile = $('#choose_file_selected');
    readURLSingle(this, file, previewSection, imagePreview, closePreviewBtn, placeholder, fileId, chooseFile, false);
  });
  $("#file-2").change(function(e) {
    var file = e.currentTarget.files[0];
    var previewSection = $('#my-preview-section');
    var imagePreview = $('#imagePreviewRes2');
    var closePreviewBtn = $('#close-preview-button2');
    var placeholder = $('#placeholder2');
    var fileId = $('#file-2');
    var chooseFile = $('#choose_file_selected2');
    readURLSingle(this, file, previewSection, imagePreview, closePreviewBtn, placeholder, fileId, chooseFile, true);
  });

  if (mobileAndTabletCheck()) {
    $("#nft_contract_attachment").change(function(e) {
      var file = e.currentTarget.files[0];
      var imagePreview = $('#imagePreview-contract');
      imagePreview.show();
      var closePreviewBtn = $('#close-preview-button-contract');
      var fileId = $('#nft_contract_attachment');
      ShowPreviewSmall(this, file, imagePreview, closePreviewBtn, fileId)
    });

    $("#nft_contract_cover").change(function(e) {
      var file = e.currentTarget.files[0];
      var imagePreview = $('#imageCover-contract');
      var closePreviewBtn = $('#close-cover-button-contract');
      var fileId = $('#nft_contract_cover');
      $('.choose_btn_cover').hide();
      $('.preview-imageCover').show();
      ShowPreviewSmall(this, file, imagePreview, closePreviewBtn, fileId)
    });
  } else {
    function readAvatarFile(input, ele) {
      if (input.files && input.files[0]) {
        var reader = new FileReader();
        reader.onload = function(e) {
          ele.croppie('bind', {
            url: e.target.result
          });
        }
        reader.readAsDataURL(input.files[0]);
      }
    }
    var $uploadAvatarCrop
    // For Profile Image
    //debugger change
    $("#nft_contract_attachment").change(function(e) {
      $('#profile_croppie_wrapper').show();
      $uploadAvatarCrop = $('#croppie_profile_preview').croppie({
        enableExif: true,
        viewport: {
          width: 250,
          height: 250,
          type: 'circle'
        },
        boundary: {
          width: 320,
          height: 320
        },
        enableOrientation: true
      });
      readAvatarFile(this, $uploadAvatarCrop)
      var imagePreview = $('#croppie_profile_preview');
      imagePreview.show();
    });

    $("#user_attachment").change(function(e) {
      $('#profile_croppie_wrapper').show();
      $uploadAvatarCrop = $('#croppie_profile_preview').croppie({
        enableExif: true,
        enableResize: true,
        viewport: {
          width: 160,
          height: 160,
          type: 'square'
        },
        boundary: {
          width: 250,
          height: 250
        },
        enableOrientation: true
      });
      readAvatarFile(this, $uploadAvatarCrop)
      var imagePreview = $('#croppie_profile_preview');
      imagePreview.show();
    });

    $('#cropImageBtn, #cropImageBtnProfile').click(function(e) {
      e.preventDefault();
      $uploadAvatarCrop.croppie('result', 'canvas').then(function(resp) {
        $('#imagePreview-contract').attr('src', resp);
        if ($(e.target).attr('id') == "cropImageBtnProfile") {
          $('#attachemnt_data').val(resp);
          $('#user_attachment').val('');
        }
        $('#imagePreview-contract').show();
        $('#profile_croppie_wrapper').hide();
        $uploadAvatarCrop.croppie('destroy');
        $('.choose_btn').addClass('after_upload_choose');
      });
    });
    $('#cropCancelBtn').click(function(e) {
      e.preventDefault();
      $uploadAvatarCrop.croppie('destroy');
      $('#profile_croppie_wrapper').hide();
      $('.choose_btn').removeClass('after_upload_choose');
      $('#user_attachment').val('');
    });
    
    // For Cover Image
    function readCoverFile(input, ele) {
      if (input.files && input.files[0]) {
        var reader = new FileReader();
        reader.onload = function(e) {
          ele.croppie('bind', {
            url: e.target.result
          });
        }
        reader.readAsDataURL(input.files[0]);
      }
    }

    var $uploadCoverCrop
    $("#nft_contract_cover, #user_banner").change(function(e) {
      $('#cover_croppie_wrapper').show();
      $uploadCoverCrop = $('#croppie_cover_preview').croppie({
        enableExif: true,
        enableResize: true,
        viewport: {
          width: 580,
          height: 200,
          type: 'square'
        },
        boundary: {
          width: 600,
          height: 300
        },
        enableOrientation: true
      });
      readCoverFile(this, $uploadCoverCrop)
      var imagePreview = $('#croppie_cover_preview');
      imagePreview.show();
    });

    $('#cropCoverBtn,#cropCoverBtnBanner').click(function(e) {
      e.preventDefault();
      $uploadCoverCrop.croppie('result', 'canvas').then(function(resp) {
        $('#coverPreview-contract').attr('src', resp);
        if ($(e.target).attr('id') == "cropCoverBtnBanner") {
          $('#attachemnt_data_banner').val(resp);
          $('#user_banner').val('');
        }
        $('#coverPreview-contract').show();
        $('#cover_croppie_wrapper').hide();
        $uploadCoverCrop.croppie('destroy');
        $('.choose_btn_cover').addClass('after_upload_choose');
      });
    });

    $('#coverCancelBtn').click(function(e) {
      e.preventDefault();
      $uploadCoverCrop.croppie('destroy');
      $('#cover_croppie_wrapper').hide();
      $('.choose_btn_cover').removeClass('after_upload_choose');
      $('#user_banner').val('');
    });
  }
  
  $('#close-preview-button-contract').click(function(e) {
    var imagePreview = $('#imagePreview-contract');
    imagePreview.hide();
    var closePreviewBtn = $('#close-preview-button-contract');
    closePreviewBtn.hide();
    var fileId = $('#nft_contract_attachment');
    fileId.val('');
    fileId.show();
    // ClosePreviewSmall(this, imagePreview, closePreviewBtn, fileId)
  });

  $('#close-cover-button-contract').click(function() {
    var imagePreview = $('#imageCover-contract');
    imagePreview.hide();
    var closePreviewBtn = $('#close-cover-button-contract');
    closePreviewBtn.hide();
    var fileId = $('#nft_contract_cover');
    fileId.val('');
    fileId.show();
    $('.choose_btn_cover').show();
    $('.preview-imageCover').hide();
    // ClosePreviewSmall(imagePreview, closePreviewBtn, fileId)
  });

  function ShowPreviewSmall(input, file, imagePreview, closePreviewBtn, fileId) {
    if (input.files && input.files[0]) {
      var reader = new FileReader();
      reader.onload = function(event) {
        imagePreview.css('background-image', 'url(' + event.target.result + ')');
        imagePreview.css({
          'height': '225px'
        });
        imagePreview.css({
          'width': '300px',
          'background-size': 'cover',
          'background-repeat': 'no-repeat',
          'background-position': 'center',
          'margin-left': 'auto',
          'margin-right': 'auto',
          'border-radius': '15px'
        });
      }
      reader.readAsDataURL(file);
      closePreviewBtn.css('display', 'inline-block');
      fileId.fadeOut(100);
      imagePreview.hide();
      imagePreview.fadeIn(650);
    }
  }

  function closePreview(previewSection, imagePreview, closePreviewBtn, placeholder, fileId, chooseFile) {
    fileId.val('');
    placeholder.fadeIn(100);
    fileId.fadeIn(100);
    chooseFile.fadeIn(100);
    chooseFile.html('Choose file');
    imagePreview.css({
      'width': 'auto',
      'height': 'auto',
      'background-size': 'cover',
      'background-repeat': 'no-repeat',
      'background-position': 'center',
      'margin-left': 'auto',
      'margin-right': 'auto'
    });
    closePreviewBtn.css('display', 'none');
    imagePreview.css('background-image', 'none');
    imagePreview.html('');
    previewSection.css('background-image', 'none');
    previewSection.html('');
  }
  $('#close-preview-button').click(function() {
    var previewSection = $('#my-preview-section');
    var imagePreview = $('#imagePreviewRes');
    var closePreviewBtn = $('#close-preview-button');
    var placeholder = $('#placeholder');
    var fileId = $('#file-1');
    var chooseFile = $('#choose_file_selected');
    closePreview(previewSection, imagePreview, closePreviewBtn, placeholder, fileId, chooseFile);
    $('.coverUpload').addClass("hide");
    $('#file-2').prop('required', false);
  });
  $('#close-preview-button2').click(function() {
    var previewSection = $('#my-preview-section');
    var imagePreview = $('#imagePreviewRes2');
    var closePreviewBtn = $('#close-preview-button2');
    var placeholder = $('#placeholder2');
    var fileId = $('#file-2');
    var chooseFile = $('#choose_file_selected2');
    closePreview(previewSection, imagePreview, closePreviewBtn, placeholder, fileId, chooseFile);
  });
  // $('input[name=chooseCollection]').change(function(){
  //     var value = $( 'input[name=chooseCollection]:checked' ).val();
  //     alert(value);
  // });
  $('#token-maximize').click(function() {
    $('.token-section').addClass('main-div-js-element');
    $('.display-section-heart-maximize').css('display', 'none');
    $('.display-section-heart-minimize').css('display', 'block');
    $('.heading-token-details-mm').css('display', 'block');
    $('.token-image').addClass('img-div-js-element');
    $('.token-image img').addClass('img-js-element');
    $('.image_get_attachment').addClass('height-auto-token');
  });
  $('#token-minimize').click(function() {
    $('.token-section').removeClass('main-div-js-element');
    $('.display-section-heart-maximize').css('display', 'flex');
    $('.display-section-heart-minimize').css('display', 'none');
    $('.heading-token-details-mm').css('display', 'none');
    $('.token-image').removeClass('img-div-js-element');
    $('.token-image img').removeClass('img-js-element');
    $('.image_get_attachment').removeClass('height-auto-token');
  });
  async function checkNetwork() {
    if (window.web3 && window.web3.eth) {
      const netid = await web3.eth.getChainId();
      console.log(netid)
      if (netid == chainId) {
        //$(".loading-gif-network").hide();
        loadBalance()
      } else {
        //$(".loading-gif-network").show();
      }
    }
  }

  function loadBalance() {
    if (window.web3 && window.web3.eth) {
      window.updateEthBalance()
    }
  }
  window.clearToastr = async function clearToastr() {
    $('.toast').remove();
  }
  setInterval(function() {
    checkNetwork()
  }, 10000);
  window.show_modal = async function show_modal(id) {
    $.magnificPopup.open({
      closeOnBgClick: false,
      enableEscapeKey: false,
      items: {
        src: id
      },
      type: 'inline'
    });
  }
});
