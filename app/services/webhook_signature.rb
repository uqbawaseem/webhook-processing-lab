require "openssl"
class WebhookSignature
  TOLERANCE = 300
  FORMAT = /\At=(\d{1,12}),v1=([a-f0-9]{64})\z/

  def self.valid?(body:, header:, secret:, now: Time.current.to_i)
    return false if secret.to_s.empty?
    match = FORMAT.match(header.to_s)
    return false unless match
    timestamp = match[1].to_i
    return false if (now - timestamp).abs > TOLERANCE
    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")
    ActiveSupport::SecurityUtils.secure_compare(expected, match[2])
  end
end
