require "rails_helper"

RSpec.describe "API V1 Notification Tokens", type: :request do
  let(:user) { users(:one) }

  before do
    sign_in user
  end

  describe "POST /api/v1/notification_tokens" do
    it "creates a notification token" do
      expect {
        post api_v1_notification_tokens_path, params: {token: "test", platform: "iOS"}
      }.to change(NotificationToken, :count).by(1)
      expect(response).to have_http_status(:success)
    end
  end

  describe "DELETE /api/v1/notification_tokens/:token" do
    it "deletes a notification token" do
      user.notification_tokens.create!(token: "test", platform: "iOS")
      expect {
        delete api_v1_notification_token_path(token: "test")
      }.to change(NotificationToken, :count).by(-1)
      expect(response).to have_http_status(:success)
    end

    it "returns 404 for missing token" do
      expect {
        delete api_v1_notification_token_path(token: "missing")
      }.not_to change(NotificationToken, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
