unless Rails.env.test?
  %w[WEBHOOK_SECRET ADMIN_TOKEN].each do |key|
    value = ENV[key].to_s
    if value.bytesize < 32 || value.start_with?("replace-")
      raise "Set #{key} to an independently generated secret of at least 32 bytes"
    end
  end
  if ENV["WEBHOOK_SECRET"] == ENV["ADMIN_TOKEN"]
    raise "WEBHOOK_SECRET and ADMIN_TOKEN must be different"
  end
  ENV.fetch("SECRET_KEY_BASE") if Rails.env.production?
end
