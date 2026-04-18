module RequestHelper
  def json_body
    request.body.rewind
    JSON.parse(request.body.read)
  rescue JSON::ParserError
    halt 400, 'Invalid JSON'
  end
end
