class Apartment
  attr_reader :id, :price_usd, :url, :photo, :address, :latitude, :longitude,
    :created_at, :origin
  
  def initialize(params = {})
    @id = params[:id]
    @price_usd = params[:price_usd]
    @url = params[:url]
    @photo = params[:photo]
    @address = params[:address]
    @latitude = params[:latitude]
    @longitude = params[:longitude]
    @created_at = params[:created_at]
    @origin = params[:origin]
  end

  def hours_from_publication
    (Time.now - created_at).to_i / 60 / 60 unless created_at.nil?
  end

  def days_from_publication
    hours_from_publication / 24 unless created_at.nil?
  end

  def neagent?
    origin == :neagent
  end

  def onliner?
    origin == :onliner
  end

  def map_image_url
    case origin
    when :neagent then map_image_from_address
    when :onliner then map_image_from_location
    end
  end

  private

  def map_image_from_address
    address_to_url = address.gsub(/\s+/, '+')
    "http://maps.googleapis.com/maps/api/staticmap?center=Минск,+#{address_to_url}&zoom=14&scale=false&size=600x300&maptype=roadmap&format=png&visual_refresh=true&markers=icon:0%7Cshadow:true%7CМинск,+#{address_to_url}"
  end

  def map_image_from_location
    "http://maps.google.com/maps/api/staticmap?center=#{latitude},#{longitude}&zoom=14&markers=#{latitude},#{longitude}&size=500x300&sensor=TRUE_OR_FALSE"
  end
end
