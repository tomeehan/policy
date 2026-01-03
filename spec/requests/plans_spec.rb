require "rails_helper"

RSpec.describe "Plans", type: :request do
  it "redirects when there are no plans" do
    Plan.delete_all
    get "/pricing"
    expect(response).to redirect_to(root_url)
  end

  it "view pricing page when there are plans" do
    get "/pricing"

    Plan.visible.find_each do |plan|
      expect(response.body).to include(plan.name)
    end
  end

  it "enterprise plan shows up" do
    get "/pricing"

    expect(response.body).to include(I18n.t("billing.subscriptions.plan.contact_us"))
  end
end
