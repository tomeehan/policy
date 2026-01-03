require "rails_helper"

RSpec.describe "Hotwire Native", type: :request do
  describe "unauthenticated requests" do
    it "redirects to login for regular requests" do
      get "/account/password"
      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns unauthorized for hotwire native requests" do
      get "/account/password", headers: {HTTP_USER_AGENT: "Hotwire Native iOS"}
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
