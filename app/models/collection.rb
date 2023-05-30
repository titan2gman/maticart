class Collection < ApplicationRecord
  include Searchable
  include AASM

  # enum category: [:art, :animation, :audio, :video]
  enum collection_type: [:single, :multiple]
  enum state: {pending: 1, approved: 2, burned: 3}

  self.per_page = 20

  FILE_EXTENSIONS = %w(png webp gif mp3 mp4).freeze
  CATEGORY_MAPPINGS = {art: ["png", "webp"], animation: ["gif"], audio: ["mp3"], video: ["mp4"]}.freeze
  IMAGE_SIZE = {thumb: {resize_to_limit: [500, 500]}, banner: {resize_to_limit: [500, 500]}}
  MEDIA_VARIANTS = {
    card: { limits: {memory: '1500MB'}, loader: {page: nil}, coalesce: true, resize_to_fill: [250, 250] },
    thumb60: { limits: {memory: '1500MB'}, loader: {page: nil}, coalesce: true, resize_to_fill: [60, 60] }
  }

  serialize :data, JSON
  serialize :category, Array


  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id'
  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'
  belongs_to :nft_contract, optional: true
  belongs_to :erc20_token, optional: true
  has_one_attached :attachment, dependent: :destroy
  has_one_attached :cover, dependent: :destroy
  has_many :bids
  has_many :comments
  has_many :transactions
  has_many :likes, dependent: :destroy
  has_many :activity_custom_tabs, foreign_key: :nft_id

  has_paper_trail

  default_scope { where(is_active: true) }
  default_scope { where(state: :approved) }
  default_scope { where.not(owned_tokens: 0) }
  default_scope -> { order('created_at desc') }
  scope :by_creator, lambda { |user| where(creator: user) }
  scope :on_sale, -> { where(put_on_sale: true) }
  scope :top_bids, lambda{|days| joins(:bids).order('count(bids.collection_id) DESC').group('bids.collection_id').where('bids.created_at > ?', Time.now-(days.to_i.days)).where("bids.state"=>:pending)}
  scope :filter_conditions , lambda{ |val|
    if val == 'Recently Added'
      hour = AdminUser.first.settings(:dashboard).recent_hours
      where('created_at >=?', hour.to_i.hours.ago)
    elsif val.present?
      where("category like ?", "%#{val}%")
    end
  }
  store :config, accessors: [:size, :width]
  store :data, accessors: [:highest_bid, :expire_bid_days]

  validates :name, :description, :category, :attachment, presence: true
  validates :name, length: {maximum: 100}
  validates :description, length: {maximum: 1000}
  validates :no_of_copies, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, if: :multiple? 

  # before_create :validate_and_assign_owned_token
  # before_save :validate_quantity
  after_validation :common_validation
  before_save :update_put_on_sale
  after_save :initiate_notification

  aasm column: :state, enum: true, whiny_transitions: false do
    state :pending, initial: true
    state :approved
    state :burned

    event :approve do
      transitions from: :pending, to: :approved
    end

    event :burn, after: :send_burn_notification do
      transitions from: :approved, to: :burned
    end
  end

  settings number_of_shards:1 do
    mapping dynamic:'false' do
      #indexes :id, type: :index
      indexes :name
      indexes :description
      indexes :category, type: :keyword
      indexes :collection_type, type: :keyword
      indexes :no_of_copies
      indexes :creator_name
      indexes :owner_name
      indexes :collection_name
      indexes :creator_address
      indexes :owner_address
      indexes :address
      indexes :country
      indexes :country_name
    end
  end

  def country_name
    if country.present?
      c_name = ISO3166::Country[country]
      c_name.translations[I18n.locale.to_s] || c_name.name
    end
  end

  def as_indexed_json(options=nil)
    self.as_json(only: [:address,:name,:description,:category,:collection_type,:no_of_copies,:country], methods: [:creator_name,:owner_name,:creator_address,:owner_address,:country_name])
  end

  def send_burn_notification
    Notification.notify_burn_token(self)
  end

  def title
    "#{name.camelcase} #{'/' if total_editions.present?} #{total_editions}"
  end

  def video_nft
    ["application/ogg", "application/ogg", "video/ogg", "audio/ogg", "video/mp4", "video/mp4", "audio/mpeg", "audio/mpeg"].include?(attachment.content_type)
  end

  def title_desc
    price, currency = sale_price
    fiat_price = sale_price_to_fiat(price, currency)
    "#{price} #{currency} #{'<span class=\'para-color\'>($ ' + fiat_price.to_s + ')</span>' if fiat_price > 0}".html_safe
  end

  def sale_price
    return [instant_sale_price.to_s, "MATIC"] if instant_sale_enabled
    # return [max_bid.amount, max_bid.crypto_currency_type] if max_bid
    return [''] if max_bid
    return ['No active bids yet.'] if put_on_sale?
    return ['Not for sale.']
  end

  # CURRENTLY ITS FOR MATIC/WMATIC. FOR OTHER FIAT NEED TO INTEGRATE COINGECKO OR COINMARKETCAP APIS
  def sale_price_to_fiat price, currency='eth'
    return 0 unless currency
    usd_price = Rails.cache.fetch "#{currency}_price", expires_in: 10.seconds do
      Api::Etherscan.usd_price(currency.downcase)
    end
    return (price.to_f * usd_price).round(2)
  end

  def collection_info(base_url, collection_shared)
    if !collection_shared
      "<div class='d-flex flex-column'>
        <a href='#{base_url}/nft_contracts/#{nft_contract&.address}'>
        <p class='para-color'>#{nft_contract&.name&.upcase} - #{nft_contract&.erc_type}#{[' -',self.no_of_copies,'editions'].join(' ') if self.total_editions.present?}</p>
        </a>
        <div class='d-flex'>
          <a href='#{Rails.application.credentials.matic_url}/address/#{nft_contract&.address}'>
            <p class='para-color mt-6 w-90'>
              <input type='text' id='nft-address' class='nft_address' value=#{nft_contract&.address&.first(5)}....#{nft_contract&.address&.last(3)} />
            </p>
          </a>
          <button class='copy_nft_address' value='#{nft_contract&.address}' data-toggle='tooltip' data-placement='right' title='Copy'><i class='fa fa-copy'></i>
          </button>
          <p class='mt-6 ml-26'><b>ID: #{self.token}</b></p>
        </div>
      </div>".html_safe
    else
      "<div class='d-flex flex-column'>
        <p class='para-color'>#{nft_contract&.name&.upcase} - #{nft_contract&.erc_type}#{[' -',self.no_of_copies,'editions'].join(' ') if self.total_editions.present?}</p>
        <div class='d-flex'>
          <a href='#{Rails.application.credentials.matic_url}/address/#{nft_contract&.address}'>
            <p class='para-color mt-6 w-90'>
              <input type='text' id='nft-address' class='nft_address' value=#{nft_contract&.address&.first(5)}....#{nft_contract&.address&.last(3)} />
            </p>
          </a>
          <button class='copy_nft_address' value='#{nft_contract&.address}' data-toggle='tooltip' data-placement='right' title='Copy'><i class='fa fa-copy'></i>
          </button>
          <p class='mt-6 ml-26'><b>ID: #{self.token}</b></p>
        </div>
      </div>".html_safe
    end
  end

  def total_editions(format=:long)
    return nil if no_of_copies == 1
    case format
    when :card
      prefix = ""
      suffix = ""
      copies = no_of_copies
      copies_s = no_of_copies.to_s
      if copies >= 1000000
        if copies % 100000 != 0
          prefix = "~"
          copies = copies - (copies % 100000)
        end
        copies = copies / 100000
        suffix = "M"
        if copies % 10 != 0
          copies_s = copies.to_s.insert(-2,".")
        else
          copies_s = (copies/10).to_s
        end
      elsif copies > 1000
        if copies % 100 != 0
          prefix = "~"
          copies = copies - (copies % 100)
        end
        copies = copies / 100
        suffix = "K"
        if copies % 10 != 0
          copies_s = copies.to_s.insert(-2,".")
        else
          copies_s = (copies/10).to_s
        end
      end
      "1&nbsp;of&nbsp;#{prefix}#{copies_s}#{suffix}"
    when :full
      #t("dashboard.limited_edition",no_of_copies: no_of_copies)
      "Limited Edition of #{no_of_copies} editions"
    else
      "#{owned_tokens.to_i} of #{no_of_copies}"
    end
  end

  def creator_name
    self.creator.name
  end

  def owner_name
    self.owner.name
  end

  def owner_address
    self.owner.address
  end

  def creator_address
    self.creator.address
  end

  def collection_name
    self.nft_contract.address if self.nft_contract.present?
  end

  def place_bid(bidding_params)
    details = bidding_params[:details]
    erc20_token = Erc20Token.where(address: details[:payment_token_address]).first
    self.bids.create(sign: bidding_params[:sign], amount: details[:amount], amount_with_fee: details[:amount_with_fee], state: :pending, owner_id: self.owner_id,
                     user_id: bidding_params[:user_id], erc20_token_id: erc20_token&.id, quantity: details[:quantity])
  end

  def execute_bid(buyer_address, bid_id, receipt)
    user = User.where(address: buyer_address).first
    bid = bids.where(id: bid_id, user_id: user.id).first
    if self.put_on_sale && bid.execute_bidding && bid.save!
      hash = {seller_id: self.owner_id, buyer_id: bid.user_id, currency: bid.crypto_currency, currency_type: bid.crypto_currency_type, channel: :bid, quantity: bid.quantity, txn_hash: receipt}
      self.hand_over_to_owner(bid.user_id, receipt, bid.quantity)
      self.add_transaction(hash)
    end
  end

  def hand_over_to_owner(new_owner_id, transaction_hash, quantity=1)
    # early bailout during transfer to self
    return self.address if self.owner_id == new_owner_id
    self_final_qty = owned_tokens - quantity
    orphan_collection = Collection.unscoped.where(nft_contract_id: nft_contract_id, token: token, owned_tokens: 0).first
    buyer_collection = Collection
                        .where.not(id: self.id) # fix users with 2 collections
                        .where(owner_id: new_owner_id, nft_contract_id: nft_contract_id, token: token).first
    if buyer_collection # buyer already has a collection for this token
      buyer_collection.assign_attributes({owned_tokens: (buyer_collection.owned_tokens + quantity)})
      if self_final_qty == 0 # hide self. it wont't be re-used
        self.update({put_on_sale: false, instant_sale_price: nil, owned_tokens: self_final_qty})
      elsif self_final_qty > 0
        self.update({owned_tokens: self_final_qty})
      end
    elsif self_final_qty == 0 # self can be re-used
      buyer_collection = self
      buyer_collection.assign_attributes({owner_id: new_owner_id, put_on_sale: false, owned_tokens: quantity, instant_sale_price: nil})
    elsif orphan_collection # re-use orphan collection
      buyer_collection = orphan_collection
      buyer_collection.assign_attributes({owner_id: new_owner_id, put_on_sale: false, owned_tokens: quantity, instant_sale_price: nil})
      self.update({owned_tokens: self_final_qty})
    else # we need to clone the collection
      buyer_collection = self.dup.tap do |destination_package|
        destination_package.attachment.attach(self.attachment.blob)
        destination_package.cover.attach(self.cover.blob) if self.cover.present?
      end
      buyer_collection.assign_attributes({owner_id: new_owner_id, address: self.class.generate_uniq_token, put_on_sale: false, owned_tokens: quantity, instant_sale_price: nil})
      self.update({owned_tokens: self_final_qty})
    end
    buyer_collection.save
    self.cancel_bids
    return buyer_collection.address
  end

  def max_bid
    self.bids.pending.order('bids.amount desc').first if self.put_on_sale
  end

  def min_bid
    self.bids.pending.order('bids.amount asc').first if self.put_on_sale
  end

  def cancel_bids
    self.bids.where(state: :pending).update_all(state: :expired)
  end

  def direct_buy(buyer, quantity, transaction_hash)
    to_update = {seller_id: self.owner_id, buyer_id: buyer.id, currency: self.instant_sale_price,
      currency_type: instant_currency_symbol, channel: :direct, quantity: quantity, txn_hash: transaction_hash}
    redirect_address = self.hand_over_to_owner(buyer.id, transaction_hash, quantity)
    tx = self.add_transaction(to_update)
    RefundTransferFeeJob.perform_in(1.minute, tx.id)
    return redirect_address
  end

  def is_owner?(user = nil)
    return false unless user
    self.owner == user
  end

  def get_attachment(user, is_background = false)
    attachment
    # if unlock_on_purchase?
    #   user.present? && user&.id == owner_id ? attachment_with_variant(:thumb) : "#{is_background ? '/assets/dummy-image.jpg' : '/assets/dummy-image.jpg'}"
    # else
    #   attachment_with_variant(:thumb)
    # end
  end

  def get_trade_count(sort_ago)
    transactions.where("created_at >= ?", ApplicationController.helpers.get_month(sort_ago)).count
  end

  def can_view_unlock_content? current_user_id=nil
    owner_id == current_user_id && unlock_on_purchase && unlock_description.present?
  end

  def self.generate_uniq_token
    rand_token = ""
    loop do
      rand_token = SecureRandom.hex
      collections = Collection.where(token: rand_token)
      break if collections.blank?
    end
    rand_token
  end

  def add_transaction(hash)
    self.transactions.create(hash)
  end

  def remove_from_sale
    self.put_on_sale = false
    self.save
  end

  def sale_rate
    copies = no_of_copies.to_f - owned_tokens.to_f
    ((copies/no_of_copies).to_f * 100)
  end

  def self.is_valid_activity(activity)
    ["state", "put_on_sale", "instant_sale_price", "owned_tokens"].any? { |x| activity.changeset.keys.include? x }
  end

  # CONVERT TO INTEGER (* 10) BY ROUND OFF BY 1 DECIMAL
  def royalty_fee
    (royalty.to_f.round(1) * 10).to_i
  end

  def self.get_with_sort_option(sort_by = nil)
    if sort_by.present?
      if sort_by == "liked"
        on_sale.where("id in (?)", joins(:likes).group(:id).order("count(collections.id) desc").pluck(:id))
      else
        on_sale.where("instant_sale_price is not null").order("instant_sale_price #{sort_by == 'lowest' ? 'asc' : 'desc'}")
      end
    else
      on_sale.order("created_at desc")
    end
  end

  # depending on the context we want to fetch scoped or unscoped collections
  #  - transactions: unscoped because we need all past transactions
  #  - owners : scoped because we do not want orphan collections where owned_tokens = 0
  def get_collections(scoped = true)
    if single?
      [self]
    else
      if scoped
        Collection.where(nft_contract_id: nft_contract_id, token: token)
      else
        Collection.unscoped.where(nft_contract_id: nft_contract_id, token: token)
      end
    end
  end

  def fetch_details(bid_id, erc20_address)
    pay_token = Erc20Token.where(address: erc20_address).first
    bid_detail = bids.where(id: bid_id).first if bid_id.present?
    details = { collection_id: self.address, owner_address: owner.address, token_id: token, unit_price: instant_sale_price,
                asset_type: nft_contract.contract_asset_type, asset_address: nft_contract.address, shared: shared?,
                seller_sign: sign_instant_sale_price, contract_type: contract_type, owned_tokens: owned_tokens }
    details = details.merge(pay_token_address: pay_token.address, pay_token_decimal: pay_token.decimals) if pay_token
    details = details.merge(buyer_address: bid_detail.user.address, amount: bid_detail.amount, amount_with_fee: bid_detail.amount_with_fee,
                            quantity: bid_detail.quantity, buyer_sign: bid_detail.sign, bid_id: bid_detail.id) if bid_detail
    return details
  end

  def change_ownership recipient_user
    self.update({owner_id: recipient_user, put_on_sale: false, instant_sale_price: nil})
  end

  def gon_data
    { service_fee: Fee.default_service_fee,
      contract_address: nft_contract&.address,
      contract_type: nft_contract&.contract_type,
      contract_shared: shared?,
      instant_sale_price: instant_sale_price,
      put_on_sale: put_on_sale
    }
  end

  def attachment_with_variant(size = nil)
    size.present? && IMAGE_SIZE[size].present? && attachment.content_type != "image/gif" ? attachment.variant(IMAGE_SIZE[size]) : attachment
  end

  def self.attachment_variation_hook
    [:card, :thumb60]
  end

  def self.cover_variation_hook
    [:card, :thumb60]
  end

  private

  def common_validation
    return if errors.present?
    self.errors.add(:royalty, "should be between 0 to 100") if royalty.present? && !royalty.between?(0, 100)
    self.errors.add(:data, "should not be blank") if validate_data
    self.errors.add(:base, "Owned tokens can't be greater than no of editions") if owned_tokens.to_i > no_of_copies.to_i
    self.errors.add(:instant_sale_price, "should be valid") if instant_sale_price.present? && instant_sale_price.to_f <= 0
  end

  def validate_data
    is_blank = false
    data.each{|k, v| is_blank = true if k.blank? || v.blank?}
    return is_blank
  end

  def update_put_on_sale
    if !self.put_on_sale? && self.put_on_sale_changed?
      self.instant_sale_enabled = false
      self.instant_sale_price = nil
      self.sign_instant_sale_price = nil
    end
  end

  def initiate_notification
    Notification.notify_put_on_sale(self) if saved_change_to_put_on_sale? && put_on_sale
    Notification.notify_price_update(self) if saved_change_to_instant_sale_price? && instant_sale_price.to_f > 0

    if saved_change_to_owner_id?
      Notification.notify_ownership_transfer(self, saved_changes['owner_id'].first) if saved_changes['owner_id'].first || saved_changes['owner_id'].last != saved_changes['creator_id'].last
      Notification.notify_nft_sold(self, saved_changes['owner_id'].first)
    end
  end

  def self.get_avtivity_user(activity)
    if activity.changeset.has_key?('owner_id')
      owner = User.find_by_id(activity.changeset['owner_id'][0])
      owner = User.find_by_id(activity.changeset['owner_id'][1]) if owner.nil?
      owner.profile_image(:icon)
    else
      activity.reify.owner.profile_image(:icon)
    end
  end
  delegate :shared?, to: :nft_contract, allow_nil: true
  delegate :contract_type, to: :nft_contract, allow_nil: true
  delegate :symbol, to: :erc20_token, prefix: :instant_currency, allow_nil: true
  delegate :address, to: :erc20_token, prefix: :instant_currency, allow_nil: true

end
