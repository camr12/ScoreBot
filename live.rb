require 'gastly'
while true
screenshot = Gastly.screenshot('http://liveladders.com/afl/', selector: '.tablesorter-green')
image = screenshot.capture
image.save('live.png')
end

