class NftContract < ApplicationRecord
  include ActiveStorageSupport::SupportForBase64
  MEDIA_VARIANTS = {
    banner: { limits: {memory: '1500MB'}, loader: {page: nil}, coalesce: true, resize_to_fill: [300, 160] },
    banner635: { limits: {memory: '1500MB'}, loader: {page: nil}, coalesce: true, resize_to_fill: [635, 160] },
    circle: { limits: {memory: '1500MB'}, loader: {page: nil}, coalesce: true, resize_to_fill: [100, 100] }
  } 

  include Rails.application.routes.url_helpers
  has_many :collections
  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id', optional: true
  #has_one_attached :attachment, dependent: :destroy
  has_one_base64_attached :attachment, dependent: :destroy
  #has_one_attached :cover, dependent: :destroy
  has_one_base64_attached :cover, dependent: :destroy
  enum contract_type: [:nft721, :nft1155]
  default_scope { where(is_active: true) }

  def self.get_shared_id type
    type == 'single' ? where(is_shared: true, contract_type: :nft721).last&.id : where(is_shared: true, contract_type: :nft1155).last&.id
  end

  def shared?
    is_shared == true
  end

  def masked_address(first_char=13, last_char=4)
    "#{address[0..first_char]}...#{address.split(//).last(last_char).join("").to_s}"
  end

  def erc_type
    case contract_type
    when :nft721.to_s
        "ERC721"
    when :nft1155.to_s
        "ERC1155"
      else
        "UNK"
    end
  end

  def contract_asset_type
    nft1155? ? 0 : 1
  end

  def self.cover_variation_hook
    [:banner, :banner635]
  end

  def self.attachment_variation_hook
    [:circle]
  end

  def attachment_url(variation = nil)
    Rails.application.routes.default_url_options[:host] = Rails.application.credentials.config[:app_url] || 'localhost:3000'
    begin
      variant = self.attachment.present? ?
      ((variation.nil? || !attachment.variant(NftContract::MEDIA_VARIANTS[variation]).processed?) ?
         attachment
         : self.attachment.variant(NftContract::MEDIA_VARIANTS[variation]).processed
      ): nil
    rescue
      # bug: sometimes the attachment ActiveStorage file is not found
      variant = self.attachment.present? ? attachment : nil
    end
    variant.nil? ? '/assets/banner-1.png' : url_for(variant)
  end

  def cover_url(variation = nil)
    Rails.application.routes.default_url_options[:host] = Rails.application.credentials.config[:app_url] || 'localhost:3000'
    begin
      variant = self.cover.present? ?
      ((variation.nil? || !cover.variant(NftContract::MEDIA_VARIANTS[variation]).processed?) ?
         cover
         : self.cover.variant(NftContract::MEDIA_VARIANTS[variation]).processed
      ): nil
    rescue
      # bug: sometimes the cover ActiveStorage file is not found
      variant = self.cover.present? ? cover : nil
    end
    variant.nil? ? '/assets/banner-1.png' : url_for(variant)
  end
end
