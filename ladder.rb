require 'gastly'
while true
  screenshot = Gastly.screenshot('http://afl.com.au/ladder', selector: '#ladder-table', timeout: 1000)
rescue
  next
  image = screenshot.capture
  image.save('ladder.png')
end
end
