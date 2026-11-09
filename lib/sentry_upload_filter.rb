require "uri"

module SentryUploadFilter
  def self.filter(event, _hint)
    request = event.request
    return event unless request

    request.headers&.delete_if { |key, _| %w[X-TreeStats-Server-Token Authorization].any? { |name| key.casecmp?(name) } }

    return event unless request.method == "POST"

    begin
      path = URI.parse(request.url.to_s).path
    rescue URI::InvalidURIError
      path = nil
    end
    return event unless path.nil? || path.empty? || ["/", "/characters", "/characters/"].include?(path)

    data = request.data
    data = JSON.parse(data) if data.is_a?(String)
    request.data = data.is_a?(Hash) ? UploadSampling.without_credentials(data) : nil
    request.cookies = nil
    request.query_string = nil
    request.env = nil
    event
  rescue JSON::ParserError
    request.data = nil
    request.cookies = nil
    request.query_string = nil
    request.env = nil
    event
  end
end
