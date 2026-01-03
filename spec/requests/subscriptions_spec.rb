require "rails_helper"

RSpec.describe "Subscriptions", type: :request do
  let(:admin) { users(:one) }
  let(:plan) { plans(:personal) }
  let(:card_token) { "tok_visa" }

  describe "admin users" do
    before do
      sign_in admin
      @account = admin.personal_account
      allow(Jumpstart::Multitenancy).to receive(:selected).and_return([])
      switch_account(@account)
    end

    it "can view billing" do
      allow(Jumpstart.config).to receive(:payments_enabled?).and_return(true)
      get billing_path
      expect(response).to have_http_status(:success)
    end

    it "can successfully update a billing email" do
      allow(Jumpstart.config).to receive(:payments_enabled?).and_return(true)
      @account.update!(billing_email: nil)
      patch billing_path, params: {account: {billing_email: "accounting@example.com"}}

      expect(response).to be_redirect
      expect(@account.reload.billing_email).not_to be_nil
    end

    it "account cannot be subscribed twice" do
      allow(Jumpstart.config).to receive(:payments_enabled?).and_return(true)
      @account.set_payment_processor :fake_processor, allow_fake: true
      @account.payment_processor.subscribe
      get checkout_path(plan: plan)
      expect(response).to redirect_to(billing_path)
      expect(flash[:alert]).to eq(I18n.t("checkouts.already_subscribed"))
    end

    it "can successfully update extra billing info" do
      allow(Jumpstart.config).to receive(:payments_enabled?).and_return(true)
      patch billing_path, params: {account: {extra_billing_info: "VAT_ID"}}

      expect(response).to be_redirect
      expect(@account.reload.extra_billing_info).to eq("VAT_ID")
    end
  end

  describe "regular users" do
    let(:regular_user) { users(:two) }
    let(:account) { accounts(:company) }

    before do
      sign_in regular_user
      allow(Jumpstart.config).to receive(:account_types).and_return("both")
      allow(Jumpstart::Multitenancy).to receive(:selected).and_return([])
      switch_account(account)
    end

    it "cannot navigate to new_subscription page" do
      allow(Jumpstart.config).to receive(:account_types).and_return("both")
      allow(Jumpstart.config).to receive(:payments_enabled?).and_return(true)
      get checkout_path(plan: plan)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t("must_be_an_admin"))
    end

    it "cannot subscribe" do
      allow(Jumpstart.config).to receive(:account_types).and_return("both")
      allow(Jumpstart.config).to receive(:payments_enabled?).and_return(true)
      post checkout_path, params: {}
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t("must_be_an_admin"))
    end

    it "cannot delete subscription" do
      account.set_payment_processor :fake_processor, allow_fake: true
      subscription = account.payment_processor.subscribe
      allow(Jumpstart.config).to receive(:payments_enabled?).and_return(true)
      delete billing_subscription_cancel_path(subscription)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(I18n.t("must_be_an_admin"))
    end
  end
end
