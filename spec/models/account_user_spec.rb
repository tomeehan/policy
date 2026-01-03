require "rails_helper"

RSpec.describe AccountUser, type: :model do
  describe "roles" do
    it "converts roles to booleans" do
      member = AccountUser.new(admin: "1")
      expect(member.admin).to eq(true)
    end

    it "can be assigned a role" do
      member = AccountUser.new(admin: true)
      expect(member.admin).to eq(true)
      expect(member.admin?).to eq(true)
    end

    it "role can be false" do
      member = AccountUser.new(admin: false)
      expect(member.admin).to eq(false)
      expect(member.admin?).to eq(false)
    end

    it "keeps track of active roles" do
      member = AccountUser.new(admin: true)
      expect(member.active_roles).to eq([:admin])
    end

    it "has no active roles" do
      member = AccountUser.new(admin: false)
      expect(member.active_roles).to be_empty
    end
  end

  describe "owner protection" do
    it "owner cannot remove the admin role" do
      member = account_users(:company_admin)
      expect(member).to be_account_owner
      member.update(admin: false)
      expect(member).not_to be_valid
    end
  end
end
