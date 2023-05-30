module Api
  class Etherscan
    ZERO = 0.0
    COINGECKO_IDS = {'matic-network': 'matic-network'}

    def self.usd_price currency='matic-network'
      erc20_price(currency)
    end

    def self.erc20_price currency='matic-network', fiat='usd'
      uri = URI.parse(Rails.application.credentials.config[:coingecko_url] + "?ids=#{COINGECKO_IDS[:'matic-network']}&vs_currencies=#{fiat}")
      
      request = Net::HTTP::Get.new(uri)
      request.content_type = "application/json"
      req_options = {
        use_ssl: uri.scheme == "https",
        open_timeout: 5,
        read_timeout: 5,
      }
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      response.code == '200' ? JSON.parse(response.body)[COINGECKO_IDS[:'matic-network']][fiat].to_f : ZERO
    end
  end
end