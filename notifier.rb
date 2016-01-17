require 'pry'
require 'pry-nav'
require 'mail'
require 'csv'
require 'yaml'
require './neagent_parser'
require './onliner_parser'


CONFIG = YAML.load(File.read('config.yml'))
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

  def just_do_it
    new_publications = fetch_new
    puts "#{new_publications.count} new!"
    send_mails_with(new_publications)
    update_db(new_publications)
  end

  private

  def open_db
    @db = CSV.open('db.txt', 'r+')
    @used_ids = db.to_a.flatten
  end

  def update_db(new_publications)
    new_publications.each { |i| db << [i.id] }
    db.close
    open_db
  end

  def fetch_new
    [OnlinerParser, NeagentParser].map do |parser|
      publication = parser.new(CONFIG['urls'][parser.to_s]).parse
      filter_old(publication)
    end.flatten
  end

  def filter_old(publications)
    publications.select { |i| !used_ids.include?(i.id) }
  end

  def new_mail(publication, recipients)
    mail = Mail.new
    mail.charset = 'UTF-8'
    mail.content_transfer_encoding = "8bit"
    mail.from = MAIL_LOGIN
    mail.to = recipients
    mail.subject = "#{publication.origin.to_s.capitalize} #{publication.price_usd}$ #{publication.address}"
    mail.html_part = letter_body_for publication
    mail
  end

  def letter_body_for(publication)
    price = publication.price_usd
    location = publication.address
    link = publication.url
    photo = publication.photo
    map = publication.map_image_url
    passed_hours = publication.hours_from_publication
    passed_days = publication.days_from_publication

    Mail::Part.new do
      content_type 'text/html; charset=UTF-8'
      body "<p>Цена: #{price}$</p><p>Адрес: #{location}</p><p>Ссылка: <a href='#{link}'>#{link}</a></p><p>Время с публикации: #{passed_days} дней #{passed_hours % 24 unless passed_hours.nil?} часов</p><img src='#{photo}'><br><img src='#{map}'>"
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
end
