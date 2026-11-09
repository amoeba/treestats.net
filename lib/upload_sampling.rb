module UploadSampling
  RATE = begin
    value = Float(ENV.fetch("UPLOAD_SAMPLE_RATE", "0"))
    raise ArgumentError unless value.finite? && value.between?(0.0, 1.0)
    value
  rescue ArgumentError
    raise ArgumentError, "UPLOAD_SAMPLE_RATE must be a number between 0 and 1"
  end

  def self.sample(text)
    return if RATE <= 0 || rand >= RATE

    text.dup
  rescue
    puts "Failed to prepare upload sample."
    nil
  end

  def self.capture(text)
    return unless text

    Sentry.with_scope do |scope|
      scope.add_attachment(bytes: text, filename: "character-upload.json", content_type: "application/json")
      Sentry.capture_message("Sampled plugin character upload")
    end
  rescue
    puts "Failed to capture upload sample."
  end

  def self.without_credentials(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, entry), result|
        next if /\A(?:key|authorization|.*(?:password|secret|token)|.*_key)\z/i.match?(key.to_s)
        result[key] = without_credentials(entry)
      end
    when Array
      value.map { |entry| without_credentials(entry) }
    else
      value
    end
  end
end
