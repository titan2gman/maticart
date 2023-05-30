class PolygonBlockJob
  include Sidekiq::Worker
  sidekiq_options queue: 'high'

  def perform(startBlockId, endBlockId = nil, thread = 1, limit = nil)
    #provider_host = URI.parse("https://matic-mumbai.chainstacklabs.com").host
    provider_host = URI.parse("https://polygon-rpc.com").host
    web3 = Web3::Eth::Rpc.new host: provider_host, port: 443, connect_options: { use_ssl: true }
    block = web3.eth.getBlockByNumber startBlockId, true
    age_sec = Time.now.to_i - block.timestamp.to_i(16)
    logger.info "#{thread} - #{startBlockId}/#{limit}, #{age_sec}"
    next_block_id = startBlockId + thread
    if endBlockId.present? and next_block_id > endBlockId
      # bail out
    elsif thread > 1 and limit.present? and next_block_id > limit
      # split bail out
    elsif thread > 1 and limit.present? and next_block_id == limit
      # join
      PolygonBlockJob.perform_async(next_block_id, endBlockId)
    elsif thread == 1 and age_sec > 600 # accelerate if more than 10 min late
      # split
      threadNum = 3
      threadNum.times { |i|
        PolygonBlockJob.perform_async(next_block_id + i,   endBlockId, threadNum, startBlockId+60)
      }
    else
      if age_sec < 60
        PolygonBlockJob.perform_in((60-age_sec).seconds, next_block_id, endBlockId, thread, limit)
      else
        PolygonBlockJob.perform_async(next_block_id, endBlockId, thread, limit)
      end
    end
  end
end
