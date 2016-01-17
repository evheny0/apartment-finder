require 'pry'
require 'pry-nav'
require 'time'
require 'mail'
require 'csv'
require 'yaml'
require './neagent_parser'
require './onliner_parser'


CONFIG = YAML.load(File.read('config.yml'))
ONLINER_URL = CONFIG['urls']['onliner']
MAIL_LOGIN = CONFIG['mail']['login']
MAIL_PASSWORD = CONFIG['mail']['password']
RECIPIENTS = CONFIG['recipients']

LOCAL_SMTP = Net::SMTP.new('smtp.gmail.com', 587)
LOCAL_SMTP.enable_starttls


class Notifier
  attr_accessor :response_hash, :db, :used_ids

  def initialize
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
    response_hash = OnlinerParser.new(ONLINER_URL).parse
    new_publications = filter_old(response_hash['apartments'])
    puts "#{new_publications.count} new!"
    send_mails_with(new_publications)
    update_db(new_publications)
  end

end
