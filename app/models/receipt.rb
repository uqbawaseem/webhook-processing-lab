class Receipt < ApplicationRecord
  belongs_to :webhook_event
  validates :invoice_id, :currency, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
end
