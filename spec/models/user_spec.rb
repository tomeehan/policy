require "rails_helper"

RSpec.describe User, type: :model do
  describe "accounts" do
    it "has many accounts" do
      user = users(:one)
      expect(user.accounts).to include(accounts(:one))
      expect(user.accounts).to include(accounts(:company))
    end

    it "has a personal account" do
      user = users(:one)
      expect(user.personal_account).to eq(accounts(:one))
    end
  end

  describe "deletion" do
    it "can delete user with accounts" do
      expect { users(:one).destroy }.to change(User, :count).by(-1)
    end
  end

  describe "ActionText representation" do
    it "renders name with ActionText to_plain_text" do
      user = users(:one)
      expect(user.attachable_plain_text_representation).to eq(user.name)
    end
  end

  describe "search" do
    it "can search users by name generated column" do
      expect(User.search("one").first).to eq(users(:one))
    end
  end
end
