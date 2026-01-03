require "rails_helper"

RSpec.describe "Users", type: :request do
  it "user can delete their account" do
    sign_in users(:one)
    expect {
      delete "/users"
    }.to change(User, :count).by(-1)
    expect(response).to redirect_to(root_path)
  end

  it "invalid time zones are handled safely" do
    user = users(:one)
    user.update!(time_zone: "invalid")

    sign_in user
    get root_path
    # May redirect to onboarding, but should not error
    expect(response).to have_http_status(:success).or have_http_status(:redirect)
  end
end
