require "rails_helper"

RSpec.describe "Account Transfers", type: :request do
  let(:account) { accounts(:company) }
  let(:admin) { users(:one) }
  let(:regular_user) { users(:two) }

  describe "admin users" do
    before { sign_in admin }

    it "can transfer account" do
      patch account_transfer_path(account), params: {user_id: regular_user.id}
      expect(response).to redirect_to(account_path(account))
      expect(account.reload.owner).to eq(regular_user)
    end
  end

  describe "regular users" do
    before { sign_in regular_user }

    it "cannot transfer account" do
      patch account_transfer_path(account)
      expect(response).to redirect_to(accounts_path)
    end
  end
end
