require 'gastly'
require 'date'

begin
  screenshot = Gastly.screenshot('http://liveladders.com/afl/', selector: '.tablesorter-green')
  image = screenshot.capture
  image.save('live.png')
  currenttime = Time.now.strftime("%d/%m/%Y %H:%M:%-S")
  puts "Saved live ladder at #{currenttime}"
rescue Gastly::FetchError => e
  puts "Got an exception, restarting."
end

while true
  begin
    screenshot = Gastly.screenshot('http://liveladders.com/afl/', selector: '.tablesorter-green', timeout:300000)
    image = screenshot.capture
    image.save('live.png')
    currenttime = Time.now.strftime("%d/%m/%Y %H:%M:%-S")
    puts "Saved live ladder at #{currenttime}"
  rescue Gastly::FetchError => e
    puts "Got an exception, restarting."
  end
end
