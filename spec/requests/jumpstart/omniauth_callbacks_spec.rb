require "rails_helper"

if defined?(OmniAuth)
  RSpec.describe "Omniauth Callbacks", type: :request do
    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.add_mock(:developer, uid: "12345", info: {email: "twitter@example.com"}, credentials: {token: 1, expires_in: 100})
    end

    it "can register and login with a social account" do
      freeze_time do
        get "/users/auth/developer/callback"

        user = User.last
        expect(user.email).to eq("twitter@example.com")
        expect(user.connected_accounts.last.provider).to eq("developer")
        expect(user.connected_accounts.last.uid).to eq("12345")
        expect(controller.current_user).to eq(user)
        expect(user.connected_accounts.last.expires_at.utc).to eq(Time.now.utc + 100)

        sign_out user
        get "/"

        expect(controller.current_user).to be_nil
        get "/users/auth/developer/callback"

        expect(controller.current_user).to eq(user)
      end
    end

    it "can connect a social account when signed in" do
      user = users(:one)

      sign_in user
      get "/users/auth/developer/callback"

      expect(user.connected_accounts.developer.last.provider).to eq("developer")
      expect(user.connected_accounts.developer.last.uid).to eq("12345")
    end

    it "cannot login with social if email is taken but not connected yet" do
      user = users(:one)
      user.connected_accounts.delete_all

      OmniAuth.config.add_mock(:developer, uid: "12345", info: {email: user.email}, credentials: {token: 1})

      get "/users/auth/developer/callback"

      expect(user.connected_accounts.developer).to be_empty
      expect(flash[:alert]).to eq(I18n.t("users.omniauth_callbacks.account_exists"))
    end

    it "can connect a social account with another model" do
      user = users(:one)
      account = user.personal_account

      sign_in user
      post "/users/auth/developer?record=#{account.to_sgid(for: :oauth, expires_in: 1.hour)}"

      expect {
        get "/users/auth/developer/callback"
      }.to change(ConnectedAccount, :count).by(1)

      expect(ConnectedAccount.last.owner).to eq(account)
    end

    it "cannot connect with account if connected to another user" do
      connected_account = connected_accounts(:one)
      user = users(:invited)

      expect(connected_account.owner).not_to eq(user)

      sign_in user
      OmniAuth.config.add_mock(:developer, uid: connected_account.uid, info: {email: connected_account.owner.email}, credentials: {token: 1})
      get "/users/auth/developer/callback"

      expect(user.connected_accounts.developer).to be_empty
      expect(flash[:alert]).to eq(I18n.t("users.omniauth_callbacks.connected_to_another_account"))
    end
  end
end
