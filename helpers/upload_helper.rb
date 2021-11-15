require "digest"

module UploadHelper
  def self.validate(text)
    return false if text.nil? or text.length <= 0

    secret = ENV["TREESTATS_SECRET"]
    return true if secret.nil?

    result = false

    begin
      l = eval "lambda { |x| #{secret} }"
    rescue SyntaxError => e
      # Allow uploads on eval exception
      puts "UploadHelper.validate: Eval failed, passing upload."

      return true
    end

    begin
      result = l.call(text)
    rescue => e
      # Allow uploads on call exception
      puts "UploadHelper.validate: Call failed, passing upload."

      return true
    end

    # TODO: Ensure we're boolean

    result
  end
end
