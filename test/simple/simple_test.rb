# Test the /send method with a fake POST

require 'net/http'
require 'json'

# uri = URI.parse("http://floating-meadow-8649.herokuapp.com/")
uri = URI.parse("http://localhost:9292")

endpoint = Net::HTTP.new(uri.host, uri.port)

files = Dir["./*.json"]

exit unless files.length > 0

files.each do |file|
  request = Net::HTTP::Post.new(uri.request_uri)
  request.body = File.open(file, 'rb') { |file| file.read }

  response = endpoint.request(request)

  puts response
end
