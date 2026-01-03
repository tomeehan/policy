require "rails_helper"

RSpec.describe AccountInvitation, type: :model do
  let(:account_invitation) { account_invitations(:one) }
  let(:account) { account_invitation.account }

  describe "validations" do
    it "cannot invite same email twice" do
      invitation = account.account_invitations.create(name: "whatever", email: account_invitation.email)
      expect(invitation).not_to be_valid
    end
  end

  describe "#accept!" do
    it "creates an account user and destroys the invitation" do
      user = users(:invited)
      expect {
        account_user = account_invitation.accept!(user)
        expect(account_user).to be_persisted
        expect(account_user.user).to eq(user)
      }.to change(AccountUser, :count).by(1)

      expect { account_invitation.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "sends notifications to account owner and inviter" do
      expect {
        account_invitations(:two).accept!(users(:invited))
      }.to change(Noticed::Notification, :count).by(2)

      event = Noticed::Event.last
      expect(event.account).to eq(account)
      expect(event.user).to eq(users(:invited))
    end
  end

  describe "#reject!" do
    it "destroys the invitation" do
      expect {
        account_invitation.reject!
      }.to change(AccountInvitation, :count).by(-1)
    end
  end
end
