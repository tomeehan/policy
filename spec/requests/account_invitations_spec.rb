require "rails_helper"

RSpec.describe "Account Invitations", type: :request do
  let(:account_invitation) { account_invitations(:one) }
  let(:account) { account_invitation.account }
  let(:inviter) { account.users.first }
  let(:invited) { users(:invited) }

  describe "when logged out" do
    it "cannot view invitation" do
      get account_invitation_path(account_invitation)
      expect(response).to redirect_to(new_user_registration_path(invite: account_invitation.token))
    end
  end

  describe "when logged in" do
    before { sign_in invited }

    it "can view invitation" do
      get account_invitation_path(account_invitation)
      expect(response).to have_http_status(:success)
    end

    it "can decline invitation" do
      expect {
        delete account_invitation_path(account_invitation)
      }.to change(AccountInvitation, :count).by(-1)
    end

    it "can accept invitation" do
      expect {
        put account_invitation_path(account_invitation)
      }.to change(AccountUser, :count).by(1)
        .and change(AccountInvitation, :count).by(-1)
    end

    it "fails to accept invitation if validation issues" do
      sign_in users(:one)
      put account_invitation_path(account_invitation)
      expect(response).to redirect_to(account_invitation_path(account_invitation))
    end
  end

  describe "sign up with invitation" do
    it "accepts invitation automatically through sign up" do
      expect {
        post user_registration_path(invite: account_invitation.token), params: {
          user: {
            name: "Invited User",
            email: "new@inviteduser.com",
            password: "password",
            password_confirmation: "password",
            terms_of_service: "1"
          }
        }
      }.to change(User, :count).by(1)

      expect(response).to be_redirect

      user = User.order(created_at: :asc).last
      expect(User.last.accounts).to include(account)
      expect { account_invitation.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
