require "digest"
class WebhooksController < ApplicationController
  MAX_BYTES = 65_536
  IDENTIFIER = /\A[a-zA-Z0-9_.:-]{1,128}\z/

  def create
    body = request.raw_post
    return render_error("payload_too_large", :content_too_large) if body.bytesize > MAX_BYTES
    unless WebhookSignature.valid?(body: body, header: request.headers["X-Webhook-Signature"], secret: ENV.fetch("WEBHOOK_SECRET"))
      return render_error("invalid_signature", :unauthorized)
    end
    payload = JSON.parse(body)
    unless payload.is_a?(Hash) && payload["id"].is_a?(String) && IDENTIFIER.match?(payload["id"]) &&
        payload["type"].is_a?(String) && IDENTIFIER.match?(payload["type"]) && payload["data"].is_a?(Hash)
      return render_error("invalid_event", :unprocessable_content)
    end
    digest = Digest::SHA256.hexdigest(body)
    begin
      event = WebhookEvent.create!(external_id: payload["id"], event_type: payload["type"],
        payload: payload, payload_digest: digest, available_at: Time.current)
      render json: { id: event.id, status: event.status, duplicate: false }, status: :accepted
    rescue ActiveRecord::RecordNotUnique
      event = WebhookEvent.find_by!(external_id: payload["id"])
      return render_error("event_id_conflict", :conflict) unless event.payload_digest == digest
      render json: { id: event.id, status: event.status, duplicate: true }, status: :ok
    end
  rescue JSON::ParserError
    render_error("invalid_json", :bad_request)
  end

  private

  def render_error(error, status)
    render json: { error: error }, status: status
  end
end
