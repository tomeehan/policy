require "rails_helper"

RSpec.describe "API Base Controller", type: :request do
  describe "authentication" do
    it "returns 401 if not logged in" do
      get api_v1_me_url
      expect(response).to have_http_status(:unauthorized)
    end

    it "succeeds when user logged in" do
      get api_v1_me_url, headers: {Authorization: "token #{users(:one).api_tokens.first.token}"}
      expect(response).to have_http_status(:success)

      # Doesn't set Devise cookies
      expect(session["warden.user.user.key"]).to be_nil
    end
  end
end
