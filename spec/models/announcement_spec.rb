require "rails_helper"

RSpec.describe Announcement, type: :model do
  describe ".unread?" do
    context "for guest" do
      it "returns false when no announcements" do
        Announcement.delete_all
        expect(Announcement.unread?(nil)).to be_falsey
      end

      it "returns true when announcements exist" do
        expect(Announcement.unread?(nil)).to be true
      end
    end

    context "for user" do
      let(:user) { users(:one) }

      it "returns false when no announcements and never read" do
        user.update(announcements_read_at: nil)
        Announcement.delete_all
        expect(Announcement.unread?(user)).to be_falsey
      end

      it "returns false when no announcements" do
        user.update(announcements_read_at: 1.month.ago)
        Announcement.delete_all
        expect(Announcement.unread?(user)).to be_falsey
      end

      it "returns true with unread announcements" do
        user.update(announcements_read_at: Announcement.maximum(:published_at) - 1.month)
        expect(Announcement.unread?(user)).to be true
      end

      it "returns false with no unread announcements" do
        user.update(announcements_read_at: Announcement.maximum(:published_at) + 1.month)
        expect(Announcement.unread?(user)).to be false
      end
    end
  end
end
