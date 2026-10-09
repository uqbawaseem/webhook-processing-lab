#!/usr/bin/env ruby
require "json"
require "openssl"
require "net/http"
require "securerandom"
secret = ENV.fetch("WEBHOOK_SECRET")
id = ARGV.fetch(0, "evt_#{SecureRandom.hex(6)}")
body = { id: id, type: "invoice.paid", data: { invoice_id: "inv_demo", amount_cents: 2500, currency: "USD" } }.to_json
stamp = Time.now.to_i
signature = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{stamp}.#{body}")
uri = URI("http://127.0.0.1:3000/webhooks/sample")
request = Net::HTTP::Post.new(uri)
request["Content-Type"] = "application/json"
request["X-Webhook-Signature"] = "t=#{stamp},v1=#{signature}"
request.body = body
response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
puts "#{response.code} #{response.body}"
exit(response.is_a?(Net::HTTPSuccess) ? 0 : 1)
