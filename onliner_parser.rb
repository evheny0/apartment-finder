require 'uri'
require 'net/https'
require 'json'
require 'time'
require './apartment'


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
    response['apartments'].map do |apartment|
      Apartment.new(id: apartment['id'].to_s,
                    price_usd: apartment['price']['usd'],
                    url: apartment['url'],
                    photo: apartment['photo'],
                    address: apartment['location']['address'],
                    latitude: apartment['location']['latitude'],
                    longitude: apartment['location']['longitude'],
                    created_at: Time.parse(apartment['created_at']),
                    origin: :onliner)
    end
  end
end
