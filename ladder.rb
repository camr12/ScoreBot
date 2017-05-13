require 'gastly'
while true
  screenshot = Gastly.screenshot('http://afl.com.au/ladder', selector: '#ladder-table', timeout: 1000)
  image = screenshot.capture
  image.save('ladder.png')
end

rescue Gastly::FetchError
  while true
    screenshot = Gastly.screenshot('http://afl.com.au/ladder', selector: '#ladder-table', timeout: 1000)
    image = screenshot.capture
    image.save('ladder.png')
  end
end
