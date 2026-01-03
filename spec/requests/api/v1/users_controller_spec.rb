require "rails_helper"

RSpec.describe "API V1 Users", type: :request do
  describe "POST /api/v1/users" do
    it "returns errors if invalid params submitted" do
      post api_v1_users_url, params: {}
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
      expect(response.parsed_body["errors"]["email"]).to eq([I18n.t("errors.messages.blank")])
    end

    it "returns user and api token on success" do
      email = "api-user@example.com"

      allow(Jumpstart.config).to receive(:register_with_account?).and_return(false)

      expect {
        post api_v1_users_url, params: {user: {email: email, name: "API User", password: "password", password_confirmation: "password", terms_of_service: "1"}}
      }.to change(User, :count).by(1)
      expect(response).to have_http_status(:success)

      expect(response.parsed_body["user"]).to be_present
      expect(response.parsed_body.dig("user", "email")).to eq(email)
      expect(response.parsed_body.dig("user", "api_tokens").first["token"]).not_to be_nil
    end

    it "turbo native registration" do
      allow(Jumpstart.config).to receive(:personal_accounts?).and_return(true)
      allow(Jumpstart.config).to receive(:register_with_account?).and_return(false)

      expect {
        post api_v1_users_url,
          params: {user: {email: "api-user@example.com", name: "API User", password: "password", password_confirmation: "password", terms_of_service: "1"}},
          headers: {HTTP_USER_AGENT: "Turbo Native iOS"}
      }.to change(User, :count).by(1)
      expect(response).to have_http_status(:success)

      user = User.last

      # Account name should match user's name
      expect(user.personal_account.name).to eq("API User")

      # Set Devise cookies for Turbo Native apps
      expect(session["warden.user.user.key"]).not_to be_nil

      # Returns an API token
      expect(response.parsed_body["token"]).to eq(user.api_tokens.find_by(name: ApiToken::APP_NAME).token)
    end

    it "registration with account" do
      allow(Jumpstart.config).to receive(:register_with_account?).and_return(true)

      expected_count = (Jumpstart.config.account_types == "team") ? 1 : 2
      expect {
        post api_v1_users_url,
          params: {user: {email: "api-user@example.com", name: "API User", password: "password", password_confirmation: "password", terms_of_service: "1", owned_accounts_attributes: [{name: "Test Account"}]}},
          headers: {HTTP_USER_AGENT: "Turbo Native iOS"}
      }.to change(Account, :count).by(expected_count)
      expect(response).to have_http_status(:success)

      account = User.order(created_at: :asc).last.accounts.find_by!(name: "Test Account")
      expect(account.account_users.first.admin).to be true
    end
  end
end
