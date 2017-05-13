require 'gastly'
require 'date'
while true
  begin
      screenshot = Gastly.screenshot('http://afl.com.au/ladder', selector: '#ladder-table', timeout:1800000)
      image = screenshot.capture
      image.save('ladder.png')
      currenttime = Time.now.strftime("%d/%m/%Y %H:%M:%-S")
      puts "Saved live ladder at #{currenttime}"
      rescue Ghastly::FetchError => e
        puts "Got an exception, restarting."
        next
      end
  end
