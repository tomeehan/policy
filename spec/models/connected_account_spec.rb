require "rails_helper"

RSpec.describe ConnectedAccount, type: :model do
  describe "access token secrets" do
    it "handles access token secrets" do
      ca = ConnectedAccount.new(access_token_secret: "test")
      expect(ca.access_token_secret).to eq("test")
    end

    it "handles empty access token secrets" do
      expect { ConnectedAccount.new(access_token_secret: "") }.not_to raise_error
    end
  end

  describe "#expired?" do
    it "returns true if token expired in the past" do
      ca = ConnectedAccount.new(expires_at: 1.hour.ago)
      expect(ca).to be_expired
    end

    it "returns true if token expires soon" do
      ca = ConnectedAccount.new(expires_at: 4.minutes.from_now)
      expect(ca).to be_expired
    end

    it "returns false if token expires in the future" do
      ca = ConnectedAccount.new(expires_at: 1.day.from_now)
      expect(ca).not_to be_expired
    end

    it "returns false if token has no expiration" do
      ca = ConnectedAccount.new(expires_at: nil)
      expect(ca).not_to be_expired
    end
  end
end
