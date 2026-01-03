require "rails_helper"

RSpec.describe "Accounts Account Invitations", type: :request do
  let(:account) { accounts(:company) }
  let(:admin) { users(:one) }
  let(:regular_user) { users(:two) }

  describe "admin users" do
    before { sign_in admin }

    it "can view invite form" do
      get new_account_account_invitation_path(account)
      expect(response).to have_http_status(:success)
    end

    it "can invite account members" do
      name, email = "Account Member", "new-member@example.com"
      expect {
        post account_account_invitations_path(account), params: {account_invitation: {name: name, email: email, admin: "0"}}
      }.to change { account.account_invitations.count }.by(1)
      expect(account.account_invitations.last).not_to be_admin
    end

    it "can invite account members with roles" do
      name, email = "Account Member", "new-member@example.com"
      expect {
        post account_account_invitations_path(account), params: {account_invitation: {name: name, email: email, admin: "1"}}
      }.to change { account.account_invitations.count }.by(1)
      expect(account.account_invitations.last).to be_admin
    end

    it "can cancel invitation" do
      expect {
        delete account_account_invitation_path(account, account.account_invitations.last)
      }.to change { account.account_invitations.count }.by(-1)
    end
  end

  describe "regular users" do
    before { sign_in regular_user }

    it "cannot view invite form" do
      get new_account_account_invitation_path(account)
      expect(response).to be_redirect
    end

    it "cannot invite account members" do
      expect {
        post account_account_invitations_path(account), params: {account_invitation: {name: "test", email: "new-member@example.com", admin: "0"}}
      }.not_to change { account.account_invitations.count }
    end

    it "cannot cancel invitation" do
      expect {
        delete account_account_invitation_path(account, account.account_invitations.last)
      }.not_to change { account.account_invitations.count }
    end
  end
end
