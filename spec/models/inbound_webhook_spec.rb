require "rails_helper"

RSpec.describe InboundWebhook, type: :model do
  include ActiveJob::TestHelper

  it "has pending as default status" do
    expect(InboundWebhook.new).to be_pending
  end

  it "enqueues incineration when processed" do
    inbound_webhook = inbound_webhooks(:fake_service)
    expect {
      inbound_webhook.processed!
    }.to have_enqueued_job(InboundWebhooks::IncinerationJob).with(inbound_webhook)
  end
end
