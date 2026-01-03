require "rails_helper"

RSpec.describe "API V1 Auth", type: :request do
  describe "POST /api/v1/auth" do
    it "returns unauthorized if user not valid" do
      post api_v1_auth_url
      expect(response).to have_http_status(:unauthorized)

      user = users(:one)
      post api_v1_auth_url, params: {email: user.email, password: "invalidpassword"}
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns an api token on successful auth" do
      user = users(:one)
      post api_v1_auth_url, params: {email: user.email, password: UNIQUE_PASSWORD}
      expect(response).to have_http_status(:success)
      expect(response.parsed_body["token"]).not_to be_nil
    end

    it "returns 422 if OTP attempt is required but not included" do
      user = users(:one)
      user.enable_two_factor!
      user.set_otp_secret!
      post api_v1_auth_url, params: {email: user.email, password: UNIQUE_PASSWORD}
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unauthorized if OTP attempt is required but incorrect" do
      user = users(:one)
      user.enable_two_factor!
      user.set_otp_secret!
      post api_v1_auth_url, params: {email: user.email, password: UNIQUE_PASSWORD, otp_attempt: "123456"}
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns an api token on successful auth with otp attempt" do
      user = users(:one)
      user.enable_two_factor!
      user.set_otp_secret!
      post api_v1_auth_url, params: {email: user.email, password: UNIQUE_PASSWORD, otp_attempt: user.current_otp}
      expect(response).to have_http_status(:success)
      expect(response.parsed_body["token"]).not_to be_nil
    end

    it "creates a new default api token if one didn't exist" do
      user = users(:one)
      expect {
        post api_v1_auth_url, params: {email: user.email, password: UNIQUE_PASSWORD}
      }.to change { user.api_tokens.count }.by(1)
      expect(response).to have_http_status(:success)
      expect(user.api_tokens.find_by(name: ApiToken::DEFAULT_NAME).token).to eq(response.parsed_body["token"])
    end

    it "sets auth cookie during hotwire app login" do
      user = users(:one)
      post api_v1_auth_url, params: {email: user.email, password: UNIQUE_PASSWORD}, headers: {HTTP_USER_AGENT: "Turbo Native iOS"}
      expect(response).to have_http_status(:success)

      # Set Devise cookies for Turbo Native apps
      expect(session["warden.user.user.key"]).not_to be_nil
    end
  end

  describe "DELETE /api/v1/auth" do
    it "destroys notification tokens on sign out" do
      notification_token = notification_tokens(:ios)

      sign_in notification_token.user
      expect {
        delete api_v1_auth_url, params: {notification_token: notification_token.token}
      }.to change(NotificationToken, :count).by(-1)
      expect(response).to have_http_status(:success)
    end

    it "destroys session" do
      sign_in users(:one)
      delete api_v1_auth_url
      expect(response).to have_http_status(:success)
    end
  end
end
