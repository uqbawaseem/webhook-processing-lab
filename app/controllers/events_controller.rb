class EventsController < ApplicationController
  before_action :authorize_admin

  def show
    event = WebhookEvent.find(params[:id])
    render json: event.slice(:id, :external_id, :event_type, :status, :attempts,
      :available_at, :last_error, :processed_at)
  end

  def replay
    event = WebhookEvent.find(params[:id])
    # Conditional UPDATE: only one concurrent replay request can reset a failed event.
    changed = WebhookEvent.where(id: event.id, status: "failed").update_all(
      status: "pending", attempts: 0, available_at: Time.current,
      lease_token: nil, lease_expires_at: nil, last_error: nil, updated_at: Time.current)
    if changed == 1
      render json: { id: event.id, status: "pending" }, status: :accepted
    else
      render json: { error: "only_failed_events_can_be_replayed" }, status: :conflict
    end
  end

  private

  def authorize_admin
    supplied = request.authorization.to_s.delete_prefix("Bearer ")
    expected = ENV.fetch("ADMIN_TOKEN")
    valid = request.authorization.to_s.start_with?("Bearer ") && expected.present? &&
      ActiveSupport::SecurityUtils.secure_compare(supplied, expected)
    render json: { error: "unauthorized" }, status: :unauthorized unless valid
  end
end
