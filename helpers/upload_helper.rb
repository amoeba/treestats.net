require "openssl"
require "rack/utils"

module UploadHelper
  def self.validate(text, signature)
    return false if text.nil? || text.length <= 0

    secret = ENV["TREESTATS_SECRET"]
    return true if secret.nil?

    return false if signature.nil? || signature.length <= 0

    digest = OpenSSL::HMAC.hexdigest("SHA256", secret, text)

    Rack::Utils.secure_compare(digest, signature)
  end
end
