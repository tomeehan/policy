require "rails_helper"

RSpec.describe "Users Connected Accounts", type: :request do
  let(:connected_account) { connected_accounts(:one) }

  before do
    sign_in connected_account.owner
  end

  it "connected accounts page" do
    get user_connected_accounts_path
    expect(response).to have_http_status(:success)
  end

  it "destroy connected account" do
    expect {
      delete user_connected_account_path(connected_account)
    }.to change(ConnectedAccount, :count).by(-1)
    expect(response).to redirect_to(user_connected_accounts_path)
  end
end
