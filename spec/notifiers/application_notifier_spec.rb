require "rails_helper"

RSpec.describe ApplicationNotifier do
  describe "#cleanup_device_token" do
    it "cleans up iOS device tokens" do
      expect {
        ApplicationNotifier.new.cleanup_device_token(
          token: notification_tokens(:ios).token,
          platform: "iOS"
        )
      }.to change(NotificationToken, :count).by(-1)
    end

    it "cleans up FCM Android device tokens" do
      expect {
        ApplicationNotifier.new.cleanup_device_token(
          token: notification_tokens(:android).token,
          platform: "fcm"
        )
      }.to change(NotificationToken, :count).by(-1)
    end
  end
end
