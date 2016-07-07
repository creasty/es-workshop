require 'faraday'
require 'faraday_middleware'

class Client

  API_URL    = ENV['ELASTICSEARCH_URL']
  INDEX_NAME = ENV['INDEX_NAME']

  %i[get post put patch delete].each do |method|
    define_method method do |uri, data = nil|
      request(method, uri, data)
    end
  end

private

  def base_path
    @base_path ||= [API_URL, INDEX_NAME].join('/')
  end

  def client
    @client ||= Faraday.new(url: base_path) do |c|
      c.request :json
      # c.response :logger
      c.response :json
      c.adapter Faraday.default_adapter
      c.options.timeout = 30
    end
  end

  def request(method, uri, data = nil)
    client.send(method, uri, data)
  end

end
