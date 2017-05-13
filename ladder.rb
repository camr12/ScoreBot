require 'gastly'
require 'date'
while true
  begin
    screenshot = Gastly.screenshot('http://afl.com.au/ladder', selector: '.tablesorter-green', timeout:1000)
    image = screenshot.capture
    image.save('live.png')
    currenttime = Time.now.strftime("%d/%m/%Y %H:%M:%-S")
    puts "Saved live ladder at #{currenttime}"
  rescue Ghastly::FetchError => e
    puts "Got an exception, restarting."
    next
  end
end
