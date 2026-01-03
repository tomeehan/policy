require "rails_helper"

RSpec.describe "Per Seat Subscription", type: :model do
  let(:account) { accounts(:fake_processor) }

  before do
    expect(account.account_users_count).to eq(1)
    account.payment_processor.subscribe(plan: "per_seat", quantity: account.account_users_count)
  end

  it "increments quantity when a user is added to the account" do
    account.account_users.create!(user: users(:one))
    expect(account.payment_processor.subscription.quantity).to eq(2)
  end

  it "decrements quantity when a user is removed from the account" do
    account.account_users.last.destroy
    expect(account.payment_processor.subscription.quantity).to eq(0)
  end
end
