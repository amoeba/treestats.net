require "uri"

module SentryUploadFilter
  def self.filter(event, _hint)
    request = event.request
    return event unless request

    request.headers&.delete_if { |key, _| key.casecmp?("X-TreeStats-Server-Token") }

    return event unless request.method == "POST"

    begin
      path = URI.parse(request.url.to_s).path
    rescue URI::InvalidURIError
      path = nil
    end
    return event unless path.nil? || path.empty? || ["/", "/characters", "/characters/"].include?(path)

    request.data = nil
    request.headers = nil
    request.cookies = nil
    request.query_string = nil
    request.env = nil
    event.user&.delete(:ip_address)
    event.user&.delete("ip_address")
    event
  end
end
