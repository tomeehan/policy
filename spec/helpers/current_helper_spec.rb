require "rails_helper"

RSpec.describe "Current Helper" do
  describe "when logged in" do
    let(:current_user) { users(:one) }

    before do
      Current.user = current_user
      Current.account = accounts(:one)
    end

    it "delegates to Current" do
      expect(Current.account).not_to be_nil
    end

    it "current_account_user" do
      expect(Current.account_user).not_to be_nil
    end

    it "current_account_admin? returns true for an admin" do
      account_user = account_users(:two)
      Current.user = account_user.user
      Current.account = account_user.account

      expect(Current.account_user).to eq(account_user)
      expect(Current.account_admin?).to be true
    end

    it "current_account_admin? returns false for a non admin" do
      account_user = account_users(:company_regular_user)
      Current.user = account_user.user
      Current.account = account_user.account

      expect(Current.account_admin?).to be false
    end

    it "current account member is from current account" do
      account_user = Current.user.account_users.last
      Current.account = account_user.account
      expect(Current.account_user).to eq(account_user)
    end

    it "current_roles" do
      Current.account = accounts(:company)
      expect(Current.roles).to eq([:admin])
    end
  end

  describe "when logged out" do
    before do
      Current.reset
    end

    it "current_account should be nil" do
      expect(Current.account).to be_nil
    end

    it "current_account_user" do
      expect(Current.account_user).to be_nil
    end

    it "current_account_admin?" do
      expect(Current.account_admin?).to be false
    end

    it "current_roles" do
      expect(Current.roles).to be_empty
    end
  end
end
