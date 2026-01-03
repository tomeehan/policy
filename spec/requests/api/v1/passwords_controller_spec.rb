require "rails_helper"

RSpec.describe "API V1 Passwords", type: :request do
  describe "PATCH /api/v1/password" do
    it "returns unauthorized if user not valid" do
      patch api_v1_password_url
      expect(response).to have_http_status(:unauthorized)
    end

    it "changes password on success" do
      user = users(:one)
      patch api_v1_password_url,
        params: {user: {current_password: UNIQUE_PASSWORD, password: "new_password", password_confirmation: "new_password"}},
        headers: {Authorization: "token #{user.api_tokens.first.token}"}
      expect(response).to have_http_status(:success)
      user.reload
      expect(user.valid_password?("new_password")).to be true
    end

    it "errors if current password doesn't match" do
      user = users(:one)
      patch api_v1_password_url,
        params: {user: {current_password: "wrong_password", password: "new_password", password_confirmation: "new_password"}},
        headers: {Authorization: "token #{user.api_tokens.first.token}"}
      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response.dig("error")).not_to be_nil
    end

    it "errors if password confirmation doesn't match" do
      user = users(:one)
      patch api_v1_password_url,
        params: {user: {current_password: UNIQUE_PASSWORD, password: "new_password", password_confirmation: "wrong_password"}},
        headers: {Authorization: "token #{user.api_tokens.first.token}"}
      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response.dig("error")).not_to be_nil
    end
  end
end
