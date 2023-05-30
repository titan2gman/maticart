module CollectionsHelper
  def cover_url(collection, variation = nil)
    return '/assets/dummy-image.jpg' if unauthorized_to_show_attachment(collection)
    attachment = ['image/png', 'image/jpeg', 'image/gif', 'image/webp'].include?(collection.attachment.content_type) ? collection.get_attachment(current_user) : collection.cover
    variant = attachment.present? ?
      ((variation.nil? || !attachment.variant(Collection::MEDIA_VARIANTS[variation]).processed?) ?
         attachment
         : attachment.variant(Collection::MEDIA_VARIANTS[variation]).processed
      ): nil
    variant.nil? ? '/assets/banner-1.png' : url_for(variant)
    # pinata_url(collection)
  end

  def attachment_tag(collection)
    attachment = collection.attachment
    return image_tag '/assets/dummy-image.jpg', class: "img-responsive" if unauthorized_to_show_attachment(collection)

    if ['audio/mp3', 'audio/webm', 'audio/mpeg'].include?(attachment.content_type)
      audio_tag url_for(attachment), size: "550x400", controls: true
    elsif ['video/mp4', 'video/webm'].include?(attachment.content_type)
      video_tag url_for(attachment), class: "video-responsive", controls: true, autoplay: "", loop: "", muted: ""
    else
      # image_tag pinata_url(collection), class: "img-responsive"
      image_tag url_for(collection.get_attachment(current_user)), class: "img-responsive"
    end
  end

  def cover_tag(collection)
    attachment = collection.attachment
    if ['audio/mp3', 'audio/webm', 'audio/mpeg'].include?(attachment.content_type)
      image_tag cover_url(collection), class: "img-responsive"
    end
  end

  def unauthorized_to_show_attachment(collection)
    # collection.unlock_on_purchase? && (!current_user.present? || (current_user && current_user != collection.owner))
    return false
  end

  def pinata_url(collection)
    collection.image_hash.present? ? "https://gateway.pinata.cloud/ipfs/#{collection.image_hash}" : '/assets/dummy-image.jpg'
  end

  def is_audio_collection?(attachment)
    ['audio/mp3', 'audio/webm', 'audio/mpeg'].include?(attachment.content_type)
  end

  def contract_path(collection)
    return 'javascript:void(0)'if collection.nft_contract.shared? 
    
    nft_contract_path(:id => collection.nft_contract.address)
  end
end
