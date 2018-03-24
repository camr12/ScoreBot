require 'gastly'
require 'date'

begin
  screenshot = Gastly.screenshot('http://afl.com.au/ladder', selector: '#c-live-ladder')
  image = screenshot.capture
  image.save('ladder.png')
  currenttime = Time.now.strftime("%d/%m/%Y %H:%M:%-S")
  puts "Saved AFL ladder at #{currenttime}"
rescue Gastly::FetchError => e
  puts "Got an exception, restarting."
end

while true
  begin
    screenshot = Gastly.screenshot('http://afl.com.au/ladder', selector: '#c-live-ladder', timeout:1800000)
    image = screenshot.capture
    image.save('ladder.png')
    currenttime = Time.now.strftime("%d/%m/%Y %H:%M:%-S")
    puts "Saved AFL ladder at #{currenttime}"
  rescue Gastly::FetchError => e
    puts "Got an exception, restarting."
  end
end
