require "rails_helper"
RSpec.describe "Event administration", type: :request do
  let(:headers) { { "Authorization" => "Bearer #{ENV.fetch('ADMIN_TOKEN')}" } }

  it "requires authentication for status and replay" do
    event = create_event
    get "/events/#{event.id}"
    expect(response).to have_http_status(:unauthorized)
    post "/events/#{event.id}/replay"
    expect(response).to have_http_status(:unauthorized)
    expect(event.reload.status).to eq("pending")
  end

  it "rejects incorrect tokens" do
    event = create_event
    get "/events/#{event.id}", headers: { "Authorization" => "Bearer wrong" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns processing status without exposing the payload" do
    event = create_event
    get "/events/#{event.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["status"]).to eq("pending")
    expect(response.parsed_body).not_to have_key("payload")
  end

  it "replays a failed event and refuses a second reset" do
    event = create_event
    event.update!(status: "failed", attempts: 3, last_error: "temporary_failure")
    post "/events/#{event.id}/replay", headers: headers
    expect(response).to have_http_status(:accepted)
    expect(event.reload.attempts).to eq(0)
    expect(event.last_error).to be_nil
    post "/events/#{event.id}/replay", headers: headers
    expect(response).to have_http_status(:conflict)
  end

  it "refuses to replay a successful event" do
    event = create_event
    EventProcessor.new.run_once
    post "/events/#{event.id}/replay", headers: headers
    expect(response).to have_http_status(:conflict)
    expect(Receipt.count).to eq(1)
  end

  it "returns 404 for an unknown ID" do
    get "/events/999999", headers: headers
    expect(response).to have_http_status(:not_found)
  end
end
