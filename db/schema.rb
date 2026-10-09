# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_08_000000) do
  create_table "receipts", force: :cascade do |t|
    t.integer "webhook_event_id", null: false
    t.string "invoice_id", null: false
    t.integer "amount_cents", null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["webhook_event_id"], name: "index_receipts_on_webhook_event_id", unique: true
  end

  create_table "webhook_events", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "event_type", null: false
    t.json "payload", null: false
    t.string "payload_digest", null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "available_at", null: false
    t.datetime "lease_expires_at"
    t.string "lease_token"
    t.string "last_error"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_webhook_events_on_external_id", unique: true
    t.index ["status", "available_at"], name: "index_webhook_events_on_status_and_available_at"
  end

  add_foreign_key "receipts", "webhook_events"
end
