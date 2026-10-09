class CreateEventsAndReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_events do |t|
      t.string :external_id, null: false
      t.string :event_type, null: false
      t.json :payload, null: false
      t.string :payload_digest, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.datetime :available_at, null: false
      t.datetime :lease_expires_at
      t.string :lease_token
      t.string :last_error
      t.datetime :processed_at
      t.timestamps
    end
    add_index :webhook_events, :external_id, unique: true
    add_index :webhook_events, [:status, :available_at]
    create_table :receipts do |t|
      t.references :webhook_event, null: false, foreign_key: true, index: {unique: true}
      t.string :invoice_id, null: false
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.timestamps
    end
  end
end
