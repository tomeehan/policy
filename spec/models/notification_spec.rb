require "rails_helper"

RSpec.describe Noticed::Notification, type: :model do
  it "notifications with user param are destroyed when user destroyed" do
    user = users(:one)
    Account::AcceptedInviteNotifier.with(user: user, account: accounts(:one)).deliver(users(:two))

    expect { user.destroy }.to change(Noticed::Notification, :count).by(-1)
  end

  it "notifications with account are destroyed when account destroyed" do
    account = accounts(:one)
    Account::OwnershipNotifier.with(previous_owner: users(:one), account: account).deliver(users(:two))

    expect { account.destroy }.to change(Noticed::Notification, :count).by(-1)
  end
end
