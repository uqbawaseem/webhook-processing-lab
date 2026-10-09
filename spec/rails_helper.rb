ENV["RAILS_ENV"] = "test"
ENV["WEBHOOK_SECRET"] = "test-webhook-" + "s" * 32
ENV["ADMIN_TOKEN"] = "test-admin-" + "a" * 32
require_relative "../config/environment"
abort("Refusing to run tests in production") if Rails.env.production?
require "rspec/rails"
require "spec_helper"
require "openssl"
ActiveRecord::Migration.maintain_test_schema!
RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include ActiveSupport::Testing::TimeHelpers
end

def sample_payload(id: "evt_001", **data)
  { id: id, type: "invoice.paid", data: { invoice_id: "inv_001", amount_cents: 2500, currency: "USD" }.merge(data) }.to_json
end

def signature(body, timestamp: Time.current.to_i)
  digest = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("WEBHOOK_SECRET"), "#{timestamp}.#{body}")
  "t=#{timestamp},v1=#{digest}"
end

def create_event(body: sample_payload)
  payload = JSON.parse(body)
  WebhookEvent.create!(external_id: payload.fetch("id"), event_type: payload.fetch("type"),
    payload: payload, payload_digest: Digest::SHA256.hexdigest(body), available_at: Time.current)
end
