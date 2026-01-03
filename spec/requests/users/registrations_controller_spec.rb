require "rails_helper"

RSpec.describe "Users::Registrations", type: :request do
  include InvisibleCaptcha

  let(:user_params) do
    params = {
      user: {
        name: "Test User",
        email: "user@test.com",
        password: "TestPassword",
        terms_of_service: "1"
      }
    }

    if Jumpstart.config.register_with_account?
      params[:user][:owned_accounts_attributes] = [{name: "Test Account"}]
    end

    params
  end

  describe "registration form" do
    it "renders successfully" do
      get new_user_registration_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("user[name]")
      expect(response.body).to include("user[email]")
      expect(response.body).to include("user[password]")
      expect(response.body).to include(InvisibleCaptcha.sentence_for_humans)
    end
  end

  describe "user registration" do
    it "succeeds with valid params" do
      expect {
        post user_registration_url, params: user_params
      }.to change(User, :count).by(1)
    end

    it "fails with empty params" do
      expect {
        post user_registration_url, params: {}
      }.not_to change(User, :count)
    end
  end

  describe "invisible captcha" do
    it "succeeds when honeypot is not filled" do
      expect {
        post user_registration_url, params: user_params.merge(honeypotx: "")
      }.to change(User, :count).by(1)
    end

    it "fails when honeypot is filled" do
      expect {
        post user_registration_url, params: user_params.merge(honeypotx: "spam")
      }.not_to change(User, :count)
    end
  end

  describe "register with account" do
    it "doesn't prompt for account details on sign up if disabled" do
      allow(Jumpstart.config).to receive(:register_with_account?).and_return(false)
      get new_user_registration_path
      expect(response.body).not_to include(I18n.t("helpers.label.account.name"))
    end

    it "prompts for account details on sign up if enabled" do
      allow(Jumpstart.config).to receive(:register_with_account?).and_return(true)
      get new_user_registration_path
      expect(response.body).to include(I18n.t("helpers.label.account.name"))
    end
  end
end
