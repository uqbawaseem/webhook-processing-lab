class WebhookEvent < ApplicationRecord
  STATUSES = %w[pending processing retrying succeeded failed].freeze
  has_one :receipt, dependent: :restrict_with_exception
  validates :external_id, :event_type, :payload_digest, :available_at, presence: true
  validates :status, inclusion: { in: STATUSES }
end
