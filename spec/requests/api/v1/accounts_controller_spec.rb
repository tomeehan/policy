require "rails_helper"

RSpec.describe "API V1 Accounts", type: :request do
  describe "GET /api/v1/accounts" do
    it "returns current user accounts" do
      user = users(:one)
      get api_v1_accounts_url, headers: {Authorization: "token #{user.api_tokens.first.token}"}
      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck("name")).to include(user.accounts.first.name)
    end
  end
end
