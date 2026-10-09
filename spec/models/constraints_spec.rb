require "rails_helper"
RSpec.describe "Persistence constraints" do
  it "enforces event uniqueness in the database, independent of model validation" do
    event = create_event
    expect { WebhookEvent.insert_all!([event.attributes.except("id")]) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "enforces one receipt per event in the database" do
    event = create_event
    InvoiceHandler.new.call(event)
    expect { Receipt.insert_all!([event.receipt.attributes.except("id")]) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end
end
