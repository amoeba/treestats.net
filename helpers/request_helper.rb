module RequestHelper
  def json_body
    request.body.rewind
    JSON.parse(request.body.read)
  end
end
