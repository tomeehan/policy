require "rails_helper"

RSpec.describe AccountMailer, type: :mailer do
  describe "#invite" do
    let(:account_invitation) { account_invitations(:one) }
    let(:mail) { AccountMailer.with(account_invitation: account_invitation).invite }

    it "has correct subject" do
      expect(mail.subject).to eq(I18n.t("account_mailer.invite.subject", inviter: "User One", account: "Company"))
    end

    it "sends to invitation email" do
      expect(mail.to).to eq([account_invitation.email])
    end

    it "sends from support email" do
      expect(mail.from).to eq([Mail::Address.new(Jumpstart.config.support_email).address])
    end

    it "includes accept or decline text" do
      expect(mail.body.encoded).to include(I18n.t("account_mailer.invite.accept_or_decline"))
    end
  end
end
