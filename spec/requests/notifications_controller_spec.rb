require "rails_helper"

RSpec.describe "Notifications", type: :request do
  before do
    sign_in users(:one)
  end

  describe "GET /notifications" do
    it "returns success" do
      get notifications_url
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /notifications/:id" do
    it "redirects to index if notification missing" do
      get notification_url(111111)
      expect(response).to redirect_to(notifications_url)
    end
  end
end
