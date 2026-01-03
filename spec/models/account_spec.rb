require "rails_helper"

RSpec.describe Account, type: :model do
  include ActiveJob::TestHelper

  describe "domain validations" do
    it "validates uniqueness of domain" do
      account = accounts(:company).dup
      expect(account).not_to be_valid
      expect(account.errors[:domain]).not_to be_empty
    end

    it "can have multiple accounts with nil domain" do
      user = users(:one)
      expect {
        Account.create!(owner: user, name: "test")
        Account.create!(owner: user, name: "test2")
      }.not_to raise_error
    end

    it "validates against reserved domains" do
      account = Account.new(domain: Jumpstart.config.domain)
      expect(account).not_to be_valid
      expect(account.errors[:domain]).not_to be_empty
    end
  end

  describe "subdomain validations" do
    it "validates uniqueness of subdomain" do
      account = accounts(:company).dup
      expect(account).not_to be_valid
      expect(account.errors[:subdomain]).not_to be_empty
    end

    it "can have multiple accounts with nil subdomain" do
      user = users(:one)
      expect {
        Account.create!(owner: user, name: "test")
        Account.create!(owner: user, name: "test2")
      }.not_to raise_error
    end

    it "validates against reserved subdomains" do
      subdomain = Account::RESERVED_SUBDOMAINS.first
      account = Account.new(subdomain: subdomain)
      expect(account).not_to be_valid
      expect(account.errors[:subdomain]).not_to be_empty
    end

    it "must start with alphanumeric char" do
      account = Account.new(subdomain: "-abcd")
      expect(account).not_to be_valid
      expect(account.errors[:subdomain]).not_to be_empty
    end

    it "must end with alphanumeric char" do
      account = Account.new(subdomain: "abcd-")
      expect(account).not_to be_valid
      expect(account.errors[:subdomain]).not_to be_empty
    end

    it "must be at least two characters" do
      account = Account.new(subdomain: "a")
      expect(account).not_to be_valid
      expect(account.errors[:subdomain]).not_to be_empty
    end

    it "can use a mixture of alphanumeric, hyphen, and underscore" do
      %w[ab 12 a-b a-9 1-2 1_2 a_3].each do |subdomain|
        account = Account.new(subdomain: subdomain)
        account.valid?
        expect(account.errors[:subdomain]).to be_empty
      end
    end
  end

  describe "personal accounts" do
    it "creates personal account when enabled" do
      allow(Jumpstart.config).to receive(:personal_accounts?).and_return(true)
      user = User.create!(name: "Test", email: "personalaccounts@example.com", password: "password", password_confirmation: "password", terms_of_service: true)
      expect(user.accounts.first).to be_personal
    end

    it "creates non-personal account when disabled" do
      allow(Jumpstart.config).to receive(:personal_accounts?).and_return(false)
      user = User.create!(name: "Test", email: "nonpersonalaccounts@example.com", password: "password", password_confirmation: "password", terms_of_service: true)
      expect(user.accounts.first).not_to be_personal
    end
  end

  describe "#owner?" do
    it "returns true for owner" do
      account = accounts(:one)
      expect(account.owner?(users(:one))).to be true
    end

    it "returns false for non-owner" do
      account = accounts(:one)
      expect(account.owner?(users(:two))).to be false
    end
  end

  describe "#can_transfer?" do
    it "returns false for personal accounts" do
      expect(accounts(:one).can_transfer?(users(:one))).to be false
    end

    it "returns true for owner of team account" do
      account = accounts(:company)
      expect(account.can_transfer?(account.owner)).to be true
    end

    it "returns false for non-owner" do
      expect(accounts(:company).can_transfer?(users(:two))).to be false
    end
  end

  describe "#transfer_ownership" do
    let(:account) { accounts(:company) }
    let(:new_owner) { users(:two) }

    it "transfers ownership to a new owner" do
      expect(account.transfer_ownership(new_owner.id)).to be_truthy
      expect(account.reload.owner).to eq(new_owner)
    end

    it "fails transferring to a user outside the account" do
      owner = account.owner
      expect(account.transfer_ownership(users(:invited).id)).to be false
      expect(account.reload.owner).to eq(owner)
    end

    it "enqueues stripe sync" do
      payment_processor = account.set_payment_processor :fake_processor, allow_fake: true
      expect {
        account.transfer_ownership(new_owner.id)
      }.to have_enqueued_job(Pay::CustomerSyncJob).with(payment_processor.id)
    end
  end

  describe "billing email" do
    let(:account) { accounts(:company) }

    it "shouldn't be included in receipts if empty" do
      account.update!(billing_email: nil)
      pay_customer = account.set_payment_processor :fake_processor, allow_fake: true
      pay_charge = pay_customer.charge(10_00)

      mail = Pay::UserMailer.with(pay_customer: pay_customer, pay_charge: pay_charge).receipt
      expect(mail.to).to eq([account.email])
    end

    it "should be included in receipts if present" do
      account.update!(billing_email: "accounting@example.com")
      pay_customer = account.set_payment_processor :fake_processor, allow_fake: true
      pay_charge = pay_customer.charge(10_00)

      mail = Pay::UserMailer.with(pay_customer: pay_customer, pay_charge: pay_charge).receipt
      expect(mail.to).to eq([account.owner.email, "accounting@example.com"])
    end
  end

  describe "noticed events cleanup" do
    it "destroys noticed events when associated" do
      account = accounts(:one)
      Noticed::Event.create!(account: account)

      expect { account.destroy }.to change(Noticed::Event, :count).by(-1)
    end

    it "destroys noticed events when associated as record" do
      account = accounts(:one)
      Noticed::Event.create!(account: accounts(:two), record: account)

      expect { account.destroy }.to change(Noticed::Event, :count).by(-1)
    end
  end

  describe "subscriptions" do
    it "can be subscribed" do
      expect(accounts(:subscribed).payment_processor).to be_subscribed
    end
  end
end
