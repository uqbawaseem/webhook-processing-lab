require "securerandom"
class EventProcessor
  MAX_ATTEMPTS = 3
  LEASE_SECONDS = 60
  RETRY_DELAYS = [5, 30].freeze

  def initialize(handler: InvoiceHandler.new, clock: -> { Time.current })
    @handler = handler
    @clock = clock
  end

  def run_once
    now = @clock.call
    # A worker can die on its final attempt. Do not leave that event processing forever.
    WebhookEvent.where(status: "processing").where("lease_expires_at <= ?", now)
      .where("attempts >= ?", MAX_ATTEMPTS).update_all(status: "failed",
        last_error: "worker_lease_expired", lease_token: nil, lease_expires_at: nil, updated_at: now)
    eligible = WebhookEvent.where(status: %w[pending retrying]).where("available_at <= ?", now)
      .or(WebhookEvent.where(status: "processing").where("lease_expires_at <= ?", now))
      .where("attempts < ?", MAX_ATTEMPTS)
    candidate = eligible.order(:available_at, :id).first
    return false unless candidate

    token = SecureRandom.uuid
    # Compare-and-swap protects against two workers choosing the same snapshot.
    claimed = eligible.where(id: candidate.id, attempts: candidate.attempts).update_all(
      status: "processing", attempts: candidate.attempts + 1, lease_token: token,
      lease_expires_at: now + LEASE_SECONDS, updated_at: now)
    return false unless claimed == 1
    process(candidate.id, token)
    true
  end

  private

  def process(id, token)
    WebhookEvent.transaction do
      # Acquire the database write lock before invoking the local handler. Completion
      # and the receipt share this transaction; neither is committed on an exception.
      owned = WebhookEvent.where(id: id, status: "processing", lease_token: token)
        .update_all(updated_at: @clock.call)
      return if owned != 1
      event = WebhookEvent.find(id)
      @handler.call(event)
      event.update!(status: "succeeded", processed_at: @clock.call,
        lease_token: nil, lease_expires_at: nil, last_error: nil)
    end
  rescue InvoiceHandler::InvalidEvent => error
    fail_attempt(id, token, retryable: false, code: error.message)
  rescue InvoiceHandler::TemporaryFailure
    fail_attempt(id, token, retryable: true, code: "temporary_failure")
  rescue StandardError => error
    # Do not persist exception messages: they may include payloads or credentials.
    Rails.logger.error("webhook event=#{id} error_class=#{error.class.name}")
    fail_attempt(id, token, retryable: false, code: "unexpected_processing_error")
  end

  def fail_attempt(id, token, retryable:, code:)
    event = WebhookEvent.find(id)
    retrying = retryable && event.attempts < MAX_ATTEMPTS
    now = @clock.call
    WebhookEvent.where(id: id, status: "processing", lease_token: token).update_all(
      status: retrying ? "retrying" : "failed", last_error: code,
      available_at: retrying ? now + RETRY_DELAYS.fetch(event.attempts - 1) : now,
      lease_token: nil, lease_expires_at: nil, updated_at: now)
  end
end
