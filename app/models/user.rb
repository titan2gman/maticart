class User < ApplicationRecord
  include Searchable
  include ActiveStorageSupport::SupportForBase64

  ACTIVITY_FILTERS = ["minted", "following", "like", "bid", "owner_bid", "my_collections"].freeze
  IMAGE_SIZE = {icon:  {resize: "50x50"}, thumb: {resize: "100x100"}, banner: {resize: "400x400"}}
  MEDIA_VARIANTS = {
    icon: { limits: {memory: '1500MB'}, loader: {page: nil}, coalesce: true, resize_to_fill: [30, 30] },
    thumb: { limits: {memory: '1500MB'}, loader: {page: nil}, coalesce: true, resize_to_fill: [160, 160] }
  }
  self.per_page = 5

  has_many :collections, foreign_key: "owner_id"
  has_many :comments
  has_one :admin_user
  has_many :created_collections, foreign_key: "creator_id", class_name: "Collection"
  has_many :follows, dependent: :destroy
  has_many :followed_users, foreign_key: :follower_id, class_name: 'Follow'
  has_many :followees, through: :followed_users
  has_many :following_users, foreign_key: :followee_id, class_name: 'Follow'
  has_many :followers, through: :following_users
  has_many :likes, dependent: :destroy
  has_many :bids
  has_many :owner_bids, foreign_key: "owner_id", class_name: "Bid"
  has_many :reports, foreign_key: "user_id", class_name: "ReportUser"
  has_many :reported, foreign_key: "created_by", class_name: "ReportUser"
  has_many :nft_contracts, foreign_key: "owner_id"
  has_many :sellings, foreign_key: "seller_id", class_name: "Transaction"
  has_many :buyings, foreign_key: "buyer_id", class_name: "Transaction"
  has_many :notifications, foreign_key: "to_user_id"
  has_many :custom_tabs, dependent: :destroy
  has_many :activity_custom_tabs, through: :custom_tabs

  has_one_base64_attached :attachment
  has_one_base64_attached :banner

  has_paper_trail

  before_create :set_approved
  before_validation :validate_name

  settings number_of_shards:1 do
    mapping dynamic:'false' do
      #indexes :id, type: :index
      # indexes :name
    end
  end

  scope :active, lambda { where(is_active: true) }
  scope :top_seller, lambda { |days|
                                days ||=30
                                # seller_ids = Transaction.where('created_at >=?',days.to_i.days.ago).group('seller_id').order('count(seller_id) desc').pluck(:seller_id)
                                ids = Transaction.where('created_at >=?', days.to_i.days.ago)
                                if ids.blank?
                                  User.order('RAND()').limit(8)
                                else
                                  seller_ids = ids.group_by { |t| t.seller_id }.map { |user_id, transactions|  [user_id, transactions.map(&:currency).map(&:to_f).sum] }.sort_by { |user_id, total| total }.reverse.map{ |user_id, total| user_id }
                                  where(id: seller_ids).includes(:sellings).order(Arel.sql("field(id, #{seller_ids.join(',')})"))
                                end
                            }
  scope :top_buyer, lambda { |days|
                                days ||=30
                                # buyer_ids = Transaction.where('created_at >=?',days.to_i.days.ago).group('buyer_id').order('count(buyer_id) desc').pluck(:buyer_id)
                                ids = Transaction.where('created_at >=?', days.to_i.days.ago)
                                if ids.blank?
                                  User.order('RAND()').limit(8)
                                else
                                  buyer_ids = ids.group_by { |t| t.buyer_id }.map { |user_id, transactions|  [user_id, transactions.map(&:currency).map(&:to_f).sum] }.sort_by { |user_id, total| total }.reverse.map{ |user_id, total| user_id }
                                  where(id: buyer_ids).includes(:buyings).order(Arel.sql("field(id, #{buyer_ids.join(',')})"))
                                end
                            }

  USERNAME_BLACKLIST = YAML.load_file("#{Rails.root}/config/username_blacklist.yml")
  VALID_NAME_REGEX = /\A[a-zA-Z\d_ .-]+\z/i

  validates :name, format: { with: VALID_NAME_REGEX }, exclusion: USERNAME_BLACKLIST, if: :name?
  validates :artist_url, uniqueness: true, if: :artist_url?

  def self.default_image
    '/assets/default_user.png'
  end


  def self.attachment_variation_hook
    [:icon, :thumb]
  end

  def profile_image(variation = nil)
    begin
      variant = attachment.attached? ?
        ((variation.nil? || MEDIA_VARIANTS[variation].nil? || !attachment.variant(MEDIA_VARIANTS[variation]).processed?) ?
           attachment
           : attachment.variant(MEDIA_VARIANTS[variation]).processed
        ): nil
    rescue
      variant = attachment.attached? ? attachment : nil
    end
    variant.nil? ? 'default_user.png' : variant
  end

  def banner_image
    if banner.attached?
      banner
    else
      'banner-bg.jpeg'
    end
  end

  def cntnt_placeholder_img
      'dummy-image.jpg'
  end

  def full_name
    name.present? ? name : masked_address(8)
  end

  def full_name_without_masked
    name.present? ? name : address
  end

  def total_transaction(is_buy=false)
    transactions = is_buy ? buyings : sellings
    [transactions.map(&:currency).map(&:to_f).sum, Rails.application.credentials.config[:base_coin]].join(' ')
  end

  def like_collection(hash)
    #We might need to check the collection present or not.
    like = self.likes.create(collection_id: hash[:collection_id])
    like.valid?
  end

  def unlike_collection(hash)
    like = self.likes.where(collection_id: hash[:collection_id]).first
    like.destroy if like.present?
    # like.destroyed?
  end

  def all_activities(filters)
    follow_ids = Follow.where(follower_id: id).pluck(:id)
    collection_ids = collections.pluck(:id)
    like_ids = likes.pluck(:id)
    bid_ids = bids.pluck(:id)

    followee_ids = followees.pluck(:id)
    collection_ids << Collection.where("owner_id in (?)", followee_ids).pluck(:id)
    like_ids << Like.where("user_id in (?)", followee_ids).pluck(:id)
    follow_ids << Follow.where(follower_id: followee_ids).pluck(:id)
    bid_ids << Bid.where("user_id in (?)", followee_ids).pluck(:id)

    query_params = build_query_params(filters, collection_ids.flatten.uniq, like_ids.flatten.uniq, follow_ids.flatten.uniq, bid_ids.flatten.uniq)
    activities(query_params)
  end

  def self_activities(filters)
    follow_ids = Follow.where(follower_id: id).pluck(:id)
    query_params = build_activity_query_params(filters, collections.pluck(:id), likes.pluck(:id), follow_ids, bids.pluck(:id), owner_bids.pluck(:id))
    # query_params = build_query_params(filters, collections.pluck(:id), likes.pluck(:id), [], bids.pluck(:id))
    activities(query_params)
  end

  def following_activities(filters)
    followee_ids = followees.pluck(:id)
    collection_ids = Collection.where("owner_id in (?)", followee_ids).pluck(:id)
    like_ids = Like.where("user_id in (?)", followee_ids).pluck(:id)
    follow_ids = Follow.where(follower_id: followee_ids).pluck(:id)
    bid_ids = Bid.where("user_id in (?)", followee_ids).pluck(:id)

    query_params = build_query_params(filters, collection_ids, like_ids, follow_ids, bid_ids)
    activities(query_params)
  end

  def build_activity_query_params(filters, collection_ids, like_ids, follow_ids, bid_ids, owner_bid_ids, user_ids=[])
    query_params = []
    include_discard = false
    include_custom = false
    reject_ids = PaperTrail::Version.where("event=? and object_changes is null", "update").pluck(:id)
    items = PaperTrail::Version.where("id not in (?)", reject_ids)
    if filters.present?
      nft_activity_ids = []
      discard_like_ids = []
      discard_bid_ids = []
      discard_owner_bid_ids = []
      discard_tab = self.custom_tabs.find_by(tab_name: 'Discarded')
      discard_follow = items.where(item_type: "Follow", item_id: discard_tab.activity_custom_tabs.pluck(:follow_id).compact.uniq).ids
      discard_nft_ids = discard_tab.activity_custom_tabs.pluck(:nft_id).compact.uniq
      discard_collection = items.where(item_type: 'Collection', event: 'create', item_id:  (discard_nft_ids&collection_ids)).ids
      discard_like = items.where(item_type: 'Like', item_id: like_ids)
      discard_bid = items.where(item_type:'Bid', item_id: bid_ids)
      discard_owner_bid = items.where(item_type: 'Bid', item_id: owner_bid_ids)
      discard_like.each do |d|
        discard_like_ids << d.id if discard_nft_ids.include?(d.item&.collection_id)
      end

      discard_bid.each do |d|
        discard_bid_ids << d.id if discard_nft_ids.include?(d.item&.collection_id)
      end

      discard_owner_bid.each do |d|
        discard_owner_bid_ids << d.id if discard_nft_ids.include?(d.item&.collection_id)
      end
      discard_activities = (discard_follow + discard_collection + discard_like_ids + discard_bid_ids + discard_owner_bid_ids).flatten.compact.uniq
      unless filters.is_a? Array
        filters = filters.split
      end
      filters.each do |f|
        if f.to_s.include?('custom_tab')
          t = CustomTab.find_by(id: f.split('_').last)
          if t.present? && t.tab_name != 'Discarded'
            include_custom = true
            like_activity_ids = []
            bid_activity_ids = []
            owner_bid_activity_ids = []
            nft_ids = t.activity_custom_tabs.pluck(:nft_id).compact.uniq
            collection_activity = items.where(item_type: 'Collection', event: 'create', item_id:  nft_ids&collection_ids).ids
            follow_activity_ids = items.where(item_type: "Follow", item_id: t.activity_custom_tabs.pluck(:follow_id).compact.uniq).ids

            discard_like.each do |d|
              like_activity_ids << d.id if nft_ids.include?(d.item&.collection_id)
            end

            discard_bid.each do |d|
              bid_activity_ids << d.id if nft_ids.include?(d.item&.collection_id)
            end

            discard_owner_bid.each do |d|
              owner_bid_activity_ids << d.id if nft_ids.include?(d.item&.collection_id)
            end
            nft_activity_ids = (follow_activity_ids + collection_activity + like_activity_ids + bid_activity_ids + owner_bid_activity_ids ).flatten.compact.uniq
          end
          include_discard = true if t.present? && t.tab_name == 'Discarded'
        end
        case f
        when "minted"
          collection_ids = ['00000'] if collection_ids.size.zero?
          discard_collection = ['000'] if discard_collection.size.zero?
          query_params << "(item_type='Collection' and event='create' and id not in (#{discard_collection.join(',')}) and item_id in (#{collection_ids.join(',')}))" if collection_ids.present? && ACTIVITY_FILTERS.include?(f)
        when "following"
          follow_ids = ['00000'] if follow_ids.size.zero?
          query_params << ["Follow", follow_ids] if follow_ids.present? && ACTIVITY_FILTERS.include?(f)
          query_params << "(id not in (#{discard_follow.join(',')}))discarded" if discard_follow.present?
        when "like"
          like_ids = ['00000'] if like_ids.size.zero?
          query_params << ["Like", like_ids] if like_ids.present? && ACTIVITY_FILTERS.include?(f)
          query_params << "(id not in (#{discard_like_ids.join(',')}))discarded" if discard_like_ids.present?
        when "bid"
          bid_ids = ['00000'] if bid_ids.size.zero?
          query_params << ["Bid", bid_ids] if bid_ids.present? && ACTIVITY_FILTERS.include?(f)
          query_params << "(id not in (#{discard_bid_ids.join(',')}))discarded" if discard_bid_ids.present?
        when "owner_bid"
          owner_bid_ids = ['00000'] if owner_bid_ids.size.zero?
          query_params << ["Bid", owner_bid_ids] if owner_bid_ids.present? && ACTIVITY_FILTERS.include?(f)
          query_params << "(id not in (#{discard_owner_bid_ids.join(',')}))discarded" if discard_owner_bid_ids.present?
        when "transfers"
          query_params << "(object_changes like '%owner_id%' and event='update')"
        when "burns"
          query_params << "(object_changes like '%state:\n- 2\n- 3%' and event='update')"
        end
      end
      if include_discard
        discard_activities = ['000'] if discard_activities.size.zero?
        query_params << "(id in (#{discard_activities.join(',')}))discarded" if discard_activities.present?
      end

      if include_custom
        nft_activity_ids = ['000'] if nft_activity_ids.size.zero?
        query_params << "(id in (#{nft_activity_ids.join(',')}))discarded"
      end
    end
    query_params
  end

  def build_query_params(filters, collection_ids, like_ids, follow_ids, bid_ids, user_ids=[])
    query_params = []

    if filters.present?
      filters.each do |f|
        case f
        # when "minted"
        #   query_params["Collection"] = collection_ids if ACTIVITY_FILTERS.include?(f)
        # when "following"
        #   query_params["Follow"] = follow_ids if ACTIVITY_FILTERS.include?(f)
        # when "like"
        #   query_params["Like"] = like_ids if ACTIVITY_FILTERS.include?(f)
        # when "bid"
        #   query_params["Bid"] = bid_ids if ACTIVITY_FILTERS.include?(f)
        # end
        when "minted"
          # query_params << ["Collection", collection_ids] if ACTIVITY_FILTERS.include?(f)
          query_params << "(item_type='Collection' and event='create' and item_id in (#{collection_ids.join(',')}))" if collection_ids.present? && ACTIVITY_FILTERS.include?(f)
        when "following"
          query_params << ["Follow", follow_ids] if follow_ids.present? && ACTIVITY_FILTERS.include?(f)
        when "like"
          query_params << ["Like", like_ids] if like_ids.present? && ACTIVITY_FILTERS.include?(f)
        when "bid"
          query_params << ["Bid", bid_ids] if bid_ids.present? && ACTIVITY_FILTERS.include?(f)
        when "transfers"
          query_params << "(object_changes like '%owner_id%' and event='update')"
        when "burns"
          query_params << "(object_changes like '%state:\n- 2\n- 3%' and event='update')"
        end
      end
    else
      query_params << ["Collection", collection_ids] if collection_ids.present?
      query_params << ["Like", like_ids] if like_ids.present?
      query_params << ["Follow", follow_ids] if follow_ids.present?
      query_params << ["Bid", bid_ids] if bid_ids.present?
      query_params << ["User", user_ids] if user_ids.present?
    end
    query_params
  end

  def activities(query_params)
    return [] unless query_params.present?
    wher_query = ''
    # if query_params.keys.present?
    #   wher_query = "("
    #   query_params.keys.each_with_index { |k, i| wher_query << "#{' OR ' if i != 0}(item_id IN (?) AND item_type = ?)#{ ')' if query_params.keys.length-1 == i}" }
    #   wher_params = [wher_query]
    #   query_params.each { |k, v| wher_params << v; wher_params << k.to_s }
    # end
    if query_params.present?
      query_params.each_with_index do |query, i|
        if query.kind_of?(Array) and query.last.present?
          wher_query << "#{' OR ' if i != 0}(item_id IN (#{query.last.join(',')}) AND item_type = '#{query.first}')#{ ')' if query_params.length-1 == i}"
        elsif query.kind_of?(String) && !query.include?('discarded')
          wher_query << "#{' OR ' if i != 0}(#{query})#{ ')' if query_params.length-1 == i}"
        elsif query.kind_of?(String) && query.include?('discarded')
          query = query.chomp("discarded")
          wher_query << "#{' AND ' if i != 0}(#{query})#{ ')' if query_params.length-1 == i}"
        end
      end
    end
    wher_query = "(" +  wher_query if wher_query.present?
    # if wher_query.include?('AND ((discard')
    #   first_part = '('+wher_query.split('AND ((discard')[0]+')'
    #   second_part = wher_query.split('AND ((discard')[1]
    #   wher_query = first_part + 'AND ((discard' + second_part
    # end

    reject_ids = PaperTrail::Version.where("event=? and object_changes is null", "update").pluck(:id)
    items = PaperTrail::Version.where(wher_query)
    items = items.where("id not in (?)", reject_ids)
    items = items.includes(item: [
      collection: [attachment_attachment: :blob],
      user: [attachment_attachment: :blob],
      follower: [attachment_attachment: :blob],
      followee: [attachment_attachment: :blob]
    ]).order(created_at: :desc)#.paginate(page: page_no, per_page: 20)
  end

  def self.default_activities(filters, page_no = 1)
    modified_filters = []
    reject_ids = PaperTrail::Version.where("event=? and object_changes is null", "update").pluck(:id)
    items = PaperTrail::Version
    items = items.where("id not in (?)", reject_ids)
    query_params = []

    filters.each do |f|
      case f
      when "minted"
        modified_filters << "Collection"
        query_params << "(event='create')"
      when "transfers"
        query_params << "(object_changes like '%owner_id%' and event='update')"
      when "burns"
        query_params << "(object_changes like '%state:\n- 2\n- 3%' and event='update')"
      when "following"
        modified_filters << "Follow"
      when "like"
        modified_filters << "Like"
      when "bid"
        modified_filters << "Bid"
      end
    end

    items = items.where("item_type in (?)", modified_filters) if modified_filters.length > 0

    if query_params.present?
      wher_query = "("
      query_params.each_with_index { |k, i| wher_query << "#{' OR ' if i != 0}#{k}#{ ')' if query_params.length-1 == i}" }
      items = items.where(wher_query)
    end

    items.includes(item: [
      collection: [attachment_attachment: :blob],
      user: [attachment_attachment: :blob],
      follower: [attachment_attachment: :blob],
      followee: [attachment_attachment: :blob]
    ]).order(created_at: :desc).paginate(page: page_no, per_page: 50)
  end

  def notifications_activities
    followee_ids = followees.pluck(:id)
    like_ids = Like.where("user_id in (?)", followee_ids).pluck(:id)
    follow_ids = Follow.where(follower_id: followee_ids).pluck(:id)
    bid_ids = [owner_bids.pluck(:id), bids.pluck(:id)].flatten.uniq
    collection_ids = Collection.where("owner_id in (?)", followee_ids).pluck(:id)

    query_params = build_query_params([], collection_ids, like_ids, follow_ids, bid_ids, [id])
    activities(query_params)
  end

  def masked_address(first_char=13, last_char=4)
    "#{address[0..first_char]}...#{address.split(//).last(last_char).join("").to_s}"
  end

  def self.validate_user address
    where(address: address).first
  end

  def attachment_with_variant(size = nil)
    size.present? && IMAGE_SIZE[size].present? && attachment.content_type != "image/gif" ? attachment.variant(IMAGE_SIZE[size]).processed : attachment
  end

  def get_contracts(type)
    case type 
    when "single"
      self.nft_contracts.where(contract_type: 'nft721')
    when "multiple"
      self.nft_contracts.where(contract_type: 'nft1155')
    end
  end

  def bid_balance
    # default bids scope is "active bids" only
    self.bids.sum(:amount)
  end

  private

  def set_approved
    self.is_approved = Rails.application.credentials.config[:auto_approval] ? Rails.application.credentials.config[:auto_approval] : false
  end

  def validate_name
    if self.name.present?
      self.artist_url = self.name.gsub(" ", "-")
      check_name = !self.name.match(/\A0x[a-fA-F0-9]{40}\z/i)
      self.errors.add("name","blockchain address isn't allowed in name field") unless check_name
    end
  end
end
