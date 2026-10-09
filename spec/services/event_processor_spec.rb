require "rails_helper"
RSpec.describe EventProcessor do
  it "creates one receipt and does not process a successful event again" do
    event = create_event
    processor = described_class.new
    expect(processor.run_once).to eq(true)
    expect(event.reload.status).to eq("succeeded")
    expect(event.attempts).to eq(1)
    expect(event.receipt.amount_cents).to eq(2500)
    expect(processor.run_once).to eq(false)
    expect(Receipt.count).to eq(1)
  end

  it "retries a temporary failure only after its due time" do
    travel_to Time.utc(2026, 10, 8, 12) do
      event = create_event
      handler = double("handler")
      allow(handler).to receive(:call).and_raise(InvoiceHandler::TemporaryFailure)
      processor = described_class.new(handler: handler)
      processor.run_once
      expect(event.reload.status).to eq("retrying")
      expect(event.available_at).to eq(Time.current + 5)
      expect(processor.run_once).to eq(false)
      travel 5.seconds
      allow(handler).to receive(:call) { |item| InvoiceHandler.new.call(item) }
      processor.run_once
      expect(event.reload.status).to eq("succeeded")
      expect(event.attempts).to eq(2)
    end
  end

  it "stops retrying after three attempts" do
    travel_to Time.utc(2026, 10, 8, 12) do
      event = create_event
      handler = double("handler", call: nil)
      allow(handler).to receive(:call).and_raise(InvoiceHandler::TemporaryFailure)
      processor = described_class.new(handler: handler)
      processor.run_once
      travel 5.seconds
      processor.run_once
      travel 30.seconds
      processor.run_once
      expect(event.reload.status).to eq("failed")
      expect(event.attempts).to eq(3)
      expect(processor.run_once).to eq(false)
    end
  end

  it "rolls back a receipt if the handler fails after writing it" do
    event = create_event
    handler = ->(item) { InvoiceHandler.new.call(item); raise InvoiceHandler::TemporaryFailure }
    described_class.new(handler: handler).run_once
    expect(Receipt.count).to eq(0)
    expect(event.reload.status).to eq("retrying")
  end

  it "does not retry invalid invoice data" do
    event = create_event(body: sample_payload(amount_cents: -1))
    described_class.new.run_once
    expect(event.reload.status).to eq("failed")
    expect(event.last_error).to eq("invalid_invoice_data")
    expect(event.attempts).to eq(1)
  end

  it "marks unsupported event types as failed" do
    event = create_event
    event.update!(event_type: "unknown.event")
    described_class.new.run_once
    expect(event.reload.last_error).to eq("unsupported_event_type")
    expect(Receipt.count).to eq(0)
  end

  it "leaves an unexpired lease alone" do
    event = create_event
    event.update!(status: "processing", attempts: 1, lease_token: "other-worker", lease_expires_at: 1.minute.from_now)
    expect(described_class.new.run_once).to eq(false)
    expect(event.reload.attempts).to eq(1)
  end

  it "recovers an event when a worker dies before completing its lease" do
    event = create_event
    event.update!(status: "processing", attempts: 1, lease_token: "dead-worker", lease_expires_at: 1.second.ago)
    described_class.new.run_once
    expect(event.reload.status).to eq("succeeded")
    expect(event.attempts).to eq(2)
    expect(Receipt.count).to eq(1)
  end

  it "makes an exhausted expired lease terminal" do
    event = create_event
    event.update!(status: "processing", attempts: 3, lease_token: "dead-worker", lease_expires_at: 1.second.ago)
    expect(described_class.new.run_once).to eq(false)
    expect(event.reload.status).to eq("failed")
    expect(event.last_error).to eq("worker_lease_expired")
  end

  it "does not store potentially sensitive exception messages" do
    event = create_event
    handler = ->(_) { raise "private-token-in-message" }
    described_class.new(handler: handler).run_once
    expect(event.reload.last_error).to eq("unexpected_processing_error")
  end
end
