# Provides verification of incoming message's contents
require 'digest'

module Encryption
  def self.decrypt(text)
    # Fail if we don't even have enough text to do what's next
    return false unless text.length > 64
    
    message, shasum = text.split(',"key":"')
    
    message = message + "}"
    message = message.sub(/"/, "\"")
    
    shasum  = shasum[0..(shasum.length - 3)]
    
    # Fail if the shasum we find isn't 64 chars
    return false unless shasum.length == 64
    
    # Unshuffle shasum
    shasum = shasum[45..63] + shasum[0..44]
    
    # Compute message diest
    digest = Digest::SHA256.hexdigest(message)
    
    return digest == shasum
  end 
end