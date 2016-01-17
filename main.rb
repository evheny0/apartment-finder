require './notifier'


notifier = Notifier.new RAW_ADDRESS

loop do
  notifier.just_do_it
  sleep(60 * rand(10..30))
end
