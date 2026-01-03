require "rails_helper"

RSpec.describe "Jumpstart Config", type: :request do
  it "can access jumpstart config" do
    get "/jumpstart"
    expect(response).to have_http_status(:success)
  end
end
