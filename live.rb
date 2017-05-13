require 'gastly'
while true
  screenshot = Gastly.screenshot('http://liveladders.com/afl/', selector: '.tablesorter-green')
rescue
  next
  image = screenshot.capture
  image.save('live.png')
end
end
