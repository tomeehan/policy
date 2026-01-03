require "rails_helper"

RSpec.describe "Public pages", type: :request do
  it "homepage" do
    get root_path
    expect(response).to have_http_status(:success)
  end

  it "dashboard" do
    sign_in users(:one)
    get root_path
    # May redirect to onboarding if not completed
    expect(response).to have_http_status(:success).or have_http_status(:redirect)
  end
end
