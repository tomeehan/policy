require "rails_helper"

RSpec.describe "Multitenancy", type: :request do
  let(:user) { users(:one) }
  let(:account) { accounts(:company) }

  before { sign_in user }

  it "domain multitenancy" do
    allow(Jumpstart.config).to receive(:account_types).and_return("both")
    allow(Jumpstart::Multitenancy).to receive(:selected).and_return(["subdomain"])

    get user_root_path
    expect(response.body).to include(user.name)

    host! account.domain
    sign_in user

    get user_root_path
    expect(response.body).to include(account.name)
  end

  it "subdomain multitenancy" do
    allow(Jumpstart.config).to receive(:account_types).and_return("both")
    allow(Jumpstart::Multitenancy).to receive(:selected).and_return(["subdomain"])

    get user_root_path
    expect(response.body).to include(user.name)

    host! "#{account.subdomain}.example.com"
    sign_in user

    get user_root_path
    expect(response.body).to include(account.name)
  end

  it "script path multitenancy" do
    allow(Jumpstart.config).to receive(:account_types).and_return("both")
    allow(Jumpstart::Multitenancy).to receive(:selected).and_return(["path"])

    get "/"
    expect(response.body).to include(user.name)

    get "/#{account.id}/"
    expect(response.body).to include(account.name)
  end

  it "session multitenancy" do
    allow(Jumpstart.config).to receive(:account_types).and_return("both")
    allow(Jumpstart::Multitenancy).to receive(:selected).and_return([])

    get user_root_path
    expect(response.body).to include(user.name)

    switch_account(account)

    get user_root_path
    expect(response.body).to include(account.name)
  end
end
