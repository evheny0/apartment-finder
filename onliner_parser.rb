require 'uri'
require 'net/https'
require 'json'


class OnlinerParser
  attr_reader :url_string
  
  def initialize(url)
    @url_string = url
  end

  def parse
    response = make_response_hash
    format_response response
  end

  private

  def do_request
    uri = URI.parse(url_string)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(uri.request_uri)

    http.request(request)
  end

  def make_response_hash
    response = do_request
    JSON.parse(response.body)
  end

  def format_response(response)
    response
  end
end
