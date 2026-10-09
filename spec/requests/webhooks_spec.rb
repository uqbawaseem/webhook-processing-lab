require "rails_helper"
RSpec.describe "Webhook ingestion", type: :request do
  def deliver(body, header: signature(body))
    post "/webhooks/sample", params: body, headers: {
      "CONTENT_TYPE" => "application/json", "X-Webhook-Signature" => header }
  end

  it "durably accepts an event without processing it inside the request" do
    expect { deliver(sample_payload) }.to change(WebhookEvent, :count).by(1)
    expect(response).to have_http_status(:accepted)
    expect(WebhookEvent.last.status).to eq("pending")
    expect(Receipt.count).to eq(0)
  end

  it "accepts duplicate deliveries without adding another event" do
    body = sample_payload
    deliver(body)
    expect { deliver(body) }.not_to change(WebhookEvent, :count)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["duplicate"]).to eq(true)
  end

  it "rejects the same event ID with different signed content" do
    deliver(sample_payload)
    deliver(sample_payload(amount_cents: 3000))
    expect(response).to have_http_status(:conflict)
    expect(WebhookEvent.last.payload["data"]["amount_cents"]).to eq(2500)
  end

  it "rejects a tampered payload" do
    original = sample_payload
    deliver(sample_payload(amount_cents: 1), header: signature(original))
    expect(response).to have_http_status(:unauthorized)
    expect(WebhookEvent.count).to eq(0)
  end

  it "rejects missing and malformed signatures" do
    ["", "t=nope,v1=abc", "t=1,v1=#{'a' * 64},v1=#{'b' * 64}"].each do |header|
      deliver(sample_payload, header: header)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "rejects stale and future-dated signatures" do
    [-301, 301].each do |offset|
      body = sample_payload
      deliver(body, header: signature(body, timestamp: Time.current.to_i + offset))
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "returns a controlled error for signed malformed JSON" do
    deliver('{"broken":')
    expect(response).to have_http_status(:bad_request)
  end

  it "rejects signed events without the envelope fields" do
    ['[]', '{}', '{"id":"evt_1","type":"invoice.paid","data":[]}'].each do |body|
      deliver(body)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  it "rejects oversized payloads before persistence" do
    deliver({id: 'evt_large', type: 'invoice.paid', data: {padding: 'x' * 65_537}}.to_json)
    expect(response).to have_http_status(:content_too_large)
    expect(WebhookEvent.count).to eq(0)
  end
end
