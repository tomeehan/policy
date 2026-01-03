require "rails_helper"

RSpec.describe "Account Users", type: :request do
  let(:account) { accounts(:company) }
  let(:admin) { users(:one) }
  let(:regular_user) { users(:two) }

  describe "admin users" do
    before { sign_in admin }

    it "can view account users" do
      get account_path(account)
      expect(response.body).to include(account.name)
      expect(response.body).to include(I18n.t("accounts.show.edit_account"))
      expect(response.body).to include(I18n.t("accounts.show.invite"))
    end

    it "can edit account user" do
      account_user = account_users(:company_regular_user)
      get edit_account_account_user_path(account, account_user)
      expect(response.body).to include(I18n.t("helpers.submit.update", model: AccountUser.model_name.human))
    end

    it "can update account user" do
      account_user = account_users(:company_regular_user)
      put account_account_user_path(account, account_user), params: {account_user: {admin: "1"}}
      expect(response).to be_redirect
      expect(account_user.reload).to be_admin
    end

    it "can delete account users" do
      user = users(:two)
      account_user = account.account_users.find_by(user: user)
      expect {
        delete account_account_user_path(account, account_user.id)
      }.to change { account.account_users.count }.by(-1)
      expect(response).to be_redirect
    end

    it "cannot delete account owner" do
      account_user = account.account_users.find_by(user_id: account.owner_id)
      expect {
        delete account_account_user_path(account, account_user.id)
      }.not_to change { account.account_users.count }
    end

    it "disables admin role checkbox when editing owner" do
      account_user = account_users(:company_admin)
      get edit_account_account_user_path(account, account_user)
      expect(response.body).to include('disabled')
    end
  end

  describe "regular users" do
    before { sign_in regular_user }

    it "can view account users but not edit" do
      get account_path(account)
      expect(response.body).to include(account.name)
      expect(response.body).not_to include(I18n.t("accounts.show.edit_account"))
    end

    it "cannot view account user page" do
      get account_account_user_path(account, admin)
      expect(response).to redirect_to(account_path(account))
    end

    it "cannot edit account users" do
      account_user = account.account_users.find_by(user: regular_user)
      get edit_account_account_user_path(account, account_user)
      expect(response).to redirect_to(account_path(account))

      account_user = account.account_users.find_by(user: admin)
      get edit_account_account_user_path(account, account_user)
      expect(response).to redirect_to(account_path(account))
    end

    it "cannot update account users" do
      account_user = account.account_users.find_by(user: regular_user)
      put account_account_user_path(account, account_user), params: {admin: "1"}
      expect(response).to redirect_to(account_path(account))

      account_user = account.account_users.find_by(user: admin)
      put account_account_user_path(account, account_user), params: {admin: "0"}
      expect(response).to redirect_to(account_path(account))
    end

    it "cannot delete account users" do
      user = users(:one)
      account_user = account.account_users.find_by(user: user)
      delete account_account_user_path(account, account_user.id)
      expect(response).to redirect_to(account_path(account))
      expect(account.account_users.pluck(:user_id)).to include(user.id)
    end
  end
end
