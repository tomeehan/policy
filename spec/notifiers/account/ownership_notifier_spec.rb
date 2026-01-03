require "rails_helper"

RSpec.describe Account::OwnershipNotifier do
  let(:account) { accounts(:company) }
  let(:user) { users(:invited) }

  before do
    Account::OwnershipNotifier.with(account: account, record: user).save!
  end

  it "notification is deleted when account is deleted" do
    expect {
      account.destroy
    }.to change(Account::OwnershipNotifier, :count).by(-1)
  end

  it "notification is deleted when user is deleted" do
    expect {
      user.destroy
    }.to change(Account::OwnershipNotifier, :count).by(-1)
  end
end
