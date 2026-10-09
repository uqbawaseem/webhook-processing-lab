class InvoiceHandler
  class InvalidEvent < StandardError; end
  class TemporaryFailure < StandardError; end

  def call(event)
    raise InvalidEvent, "unsupported_event_type" unless event.event_type == "invoice.paid"
    data = event.payload.fetch("data")
    unless data["invoice_id"].is_a?(String) && data["invoice_id"].match?(/\A[a-zA-Z0-9_-]{1,128}\z/) &&
        data["amount_cents"].is_a?(Integer) && data["amount_cents"].positive? &&
        data["currency"].is_a?(String) && data["currency"].match?(/\A[A-Z]{3}\z/)
      raise InvalidEvent, "invalid_invoice_data"
    end
    Receipt.create!(webhook_event: event, invoice_id: data["invoice_id"],
      amount_cents: data["amount_cents"], currency: data["currency"])
  end
end
