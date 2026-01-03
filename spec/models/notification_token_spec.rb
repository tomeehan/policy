require "rails_helper"

RSpec.describe NotificationToken, type: :model do
  describe "scopes" do
    it "ios scope includes ios tokens" do
      expect(NotificationToken.ios).to include(notification_tokens(:ios))
    end

    it "android scope includes android tokens" do
      expect(NotificationToken.android).to include(notification_tokens(:android))
    end
  end
end
