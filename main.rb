require 'uri'
require 'net/https'
require 'json'
require 'awesome_print'
require 'pry'
require 'pry-nav'
require 'time'
require 'mail'
require 'csv'
require 'yaml'

CONFIG = YAML.load(File.read('config.yml'))
# raw_address = "https://ak.api.onliner.by/search/apartments?rent_type%5B%5D=2_rooms&rent_type%5B%5D=1_room&price%5Bmin%5D=50&price%5Bmax%5D=350&currency=usd&only_owner=true&page=1&bounds%5Blb%5D%5Blat%5D=53.893566235737204&bounds%5Blb%5D%5Blong%5D=27.537145614624023&bounds%5Brt%5D%5Blat%5D=53.929259696557274&bounds%5Brt%5D%5Blong%5D=27.597227096557617"
RAW_ADDRESS = "https://ak.api.onliner.by/search/apartments?price%5Bmin%5D=50&price%5Bmax%5D=400&currency=usd&only_owner=true&rent_type%5B%5D=2_rooms&bounds%5Blb%5D%5Blat%5D=53.89604452913564&bounds%5Blb%5D%5Blong%5D=27.556886672973633&bounds%5Brt%5D%5Blat%5D=53.94264951038449&bounds%5Brt%5D%5Blong%5D=27.616968154907227&page=1"
MAIL_LOGIN = CONFIG['mail']['login']
MAIL_PASSWORD = CONFIG['mail']['password']
RECIPIENTS = CONFIG['recipients']

LOCAL_SMTP = Net::SMTP.new('smtp.gmail.com', 587)
LOCAL_SMTP.enable_starttls


class OnlinerParser
  attr_reader :url_string
  attr_accessor :response_hash, :db, :used_ids

  def initialize(url)
    @url_string = url
    # puts URI.unescape(url)
    open_db
  end

  def open_db
    @db = CSV.open('db.txt', 'r+')
    @used_ids = db.to_a.flatten
  end

  def update_db(new_publications)
    new_publications.each { |i| db << [i['id']] }
    db.close
    open_db
  end

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

  def filter_old(publications)
    # ids = publications.map { |i| i['id'] }
    # ids - used_ids

    publications.select { |i| !used_ids.include?(i['id'].to_s) }
  end

  def new_mail(publication, recipients)
    mail = Mail.new
    mail.charset = 'UTF-8'
    mail.content_transfer_encoding = "8bit"
    mail.from = MAIL_LOGIN
    mail.to = recipients
    mail.subject = "#{publication['price']['usd']}$ #{publication['location']['address']}"
    mail.html_part = letter_body_for publication
    mail
  end

  def map_image_link(location)
    latitude = location['latitude']
    longitude = location['longitude']
    "http://maps.google.com/maps/api/staticmap?center=#{latitude},#{longitude}&zoom=14&markers=#{latitude},#{longitude}&size=500x300&sensor=TRUE_OR_FALSE"
  end

  def letter_body_for(publication)
    price = publication['price']['usd']
    location = publication['location']['address']
    link = publication['url']
    photo = publication['photo']
    map = map_image_link(publication['location'])
    passed_hours = (Time.now - Time.parse(publication['created_at'])).to_i / 60 / 60
    passed_days = passed_hours / 24

    Mail::Part.new do
      content_type 'text/html; charset=UTF-8'
      body "<p>Цена: #{price}$</p><p>Адрес: #{location}</p><p>Ссылка: <a href='#{link}'>#{link}</a></p><p>Время с публикации: #{passed_days} дней #{passed_hours % 24} часов</p><img src='#{photo}'><br><img src='#{map}'>"
    end    
  end

  def send_mails_with(publications)
    LOCAL_SMTP.start('gmail.com', MAIL_LOGIN, MAIL_PASSWORD, :login) do |smtp|
      publications.each do |publication|
        mail = new_mail(publication, RECIPIENTS)
        smtp.send_message(mail.to_s, MAIL_LOGIN, mail.to)
      end
    end
  end

  def just_do_it
    response_hash = make_response_hash
    new_publications = filter_old(response_hash['apartments'])
    puts "#{new_publications.count} new!"
    send_mails_with(new_publications)
    update_db(new_publications)
  end
end

parser = OnlinerParser.new RAW_ADDRESS

loop do
  parser.just_do_it
  sleep(60 * rand(10..30))
end
