require 'nokogiri'
require 'open-uri'
require 'uri'
require 'net/https'
require 'time'
require './apartment'


class NeagentParser
  attr_reader :url_string

  def initialize(url)
    @url_string = url
  end

  def parse
    page = do_request
    publications = fetch_publications page
    make_apartments(publications)
  end

  private

  def do_request
    Nokogiri::HTML(open(url_string))
  end

  def fetch_publications(page)
    page.css('.sect_body').children.css('.imd')
  end

  def make_apartments(publications)
    publications.map do |elem|
      Apartment.new(id: elem['id'],
                    price_usd: to_usd(elem.css('.itm_price')[0].text.gsub(/(BYR)|\s/, '').to_i),
                    url: elem.css('.a_more')[0]['href'],
                    photo: elem.css('.imd_photo').css('img')[0]['src'],
                    address: elem.css('em').text.gsub(/( ул., д.)|(, д.)/, ' '),
                    created_at: nil,
                    origin: :neagent)
    end
  end

  def to_usd(price)
    (price / 20000).round(-1)
  end

end
