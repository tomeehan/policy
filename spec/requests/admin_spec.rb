require "rails_helper"

RSpec.describe "Admin", type: :request do
  it "cannot access /admin logged out" do
    get "/admin"
    expect(response).to have_http_status(:not_found)
  end

  it "cannot access /admin as regular user" do
    sign_in users(:one)
    get "/admin"
    expect(response).to have_http_status(:not_found)
  end

  it "can access /admin as admin user" do
    sign_in users(:admin)
    get "/admin"
    expect(response).to have_http_status(:success)
  end
end
