require 'gastly'
require 'date'

begin
  screenshot = Gastly.screenshot('http://afl.com.au/ladder', selector: '#ladder-table')
  image = screenshot.capture
  image.save('ladder.png')
  currenttime = Time.now.strftime("%d/%m/%Y %H:%M:%-S")
  puts "Saved AFL ladder at #{currenttime}"
rescue Ghastly::FetchError => e
  puts "Got an exception, restarting."
end

while true
  begin
    screenshot = Gastly.screenshot('http://afl.com.au/ladder', selector: '#ladder-table', timeout:1800000)
