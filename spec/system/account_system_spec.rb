require "rails_helper"

RSpec.describe "Account System", type: :system do
  let(:user) { users(:one) }

  before do
    driven_by(:selenium_headless)
    login_as user, scope: :user
  end

  it "can upload avatar" do
    expect(user.avatar).not_to be_attached
    visit edit_user_registration_path
    attach_file "user[avatar]", file_fixture("avatar.jpg")
    click_button I18n.t("devise.registrations.edit.update")
    expect(page).to have_css("img[src*='avatar.jpg']")
  end
end
