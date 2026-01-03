require "rails_helper"

RSpec.describe "Accounts", type: :request do
  let(:account) { accounts(:company) }
  let(:admin) { users(:one) }
  let(:regular_user) { users(:two) }

  describe "admin users" do
    before { sign_in admin }

    it "can edit account" do
      allow(Jumpstart.config).to receive(:account_types).and_return("both")
      get edit_account_path(account)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("helpers.submit.update", model: Account.model_name.human))
    end

    it "can update account" do
      allow(Jumpstart.config).to receive(:account_types).and_return("both")
      put account_path(account), params: {account: {name: "Test Account 2"}}
      expect(response).to redirect_to(account_path(account))
      follow_redirect!
      expect(response.body).to include("Test Account 2")
    end

    it "can delete account" do
      allow(Jumpstart.config).to receive(:account_types).and_return("both")
      expect {
        delete account_path(account)
      }.to change(Account, :count).by(-1)
      expect(response).to redirect_to(accounts_path)
      expect(flash[:notice]).to eq(I18n.t("accounts.destroyed"))
    end

    it "cannot delete personal account" do
      personal_account = admin.personal_account
      expect {
        delete account_path(personal_account)
      }.not_to change(Account, :count)
      expect(flash[:alert]).to eq(I18n.t("accounts.personal.cannot_delete"))
    end
  end

  describe "regular users" do
    before { sign_in regular_user }

    it "cannot edit account" do
      get edit_account_path(account)
      expect(response).to redirect_to(account_path(account))
    end

    it "cannot update account" do
      name = account.name
      put account_path(account), params: {account: {name: "Test Account Changed"}}
      expect(response).to redirect_to(account_path(account))
      follow_redirect!
      expect(response.body).to include(name)
    end

    it "cannot delete account" do
      expect {
        delete account_path(account)
      }.not_to change(Account, :count)
      expect(response).to redirect_to(account_path(account))
    end
  end
end
