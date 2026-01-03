require "rails_helper"

RSpec.describe "API V1 Me", type: :request do
  let(:user) { users(:one) }

  describe "GET /api/v1/me" do
    it "returns current user details" do
      get api_v1_me_url, headers: {Authorization: "token #{user.api_tokens.first.token}"}
      expect(response).to have_http_status(:success)
      expect(response.parsed_body["name"]).to eq(user.name)
    end
  end

  describe "DELETE /api/v1/me" do
    it "deletes current user" do
      expect {
        delete api_v1_me_url, headers: {Authorization: "token #{user.api_tokens.first.token}"}
      }.to change(User, :count).by(-1)
      expect(response).to have_http_status(:success)
    end
  end
end
