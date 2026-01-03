# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).

return if Rails.env.production?

puts "Seeding development data..."

# Create dev user first (super admin - user.admin + account admin + member)
dev_user = User.find_or_create_by!(email: "dev@example.com") do |u|
  u.first_name = "Dev"
  u.last_name = "User"
  u.password = "password"
  u.password_confirmation = "password"
  u.confirmed_at = Time.current
  u.terms_of_service = true
end
Jumpstart.grant_system_admin!(dev_user)

# Create a team account owned by dev user
account = Account.find_or_create_by!(name: "Acme Corporation") do |a|
  a.personal = false
  a.owner = dev_user
end

# Add dev user to account with admin + member roles
dev_account_user = AccountUser.find_or_create_by!(user: dev_user, account: account) do |au|
  au.admin = true
  au.member = true
end
dev_account_user.update!(admin: true, member: true)

# Create admin user (account admin only)
admin_user = User.find_or_create_by!(email: "admin@example.com") do |u|
  u.first_name = "Admin"
  u.last_name = "User"
  u.password = "password"
  u.password_confirmation = "password"
  u.confirmed_at = Time.current
  u.terms_of_service = true
end
admin_account_user = AccountUser.find_or_create_by!(user: admin_user, account: account) do |au|
  au.admin = true
  au.member = false
end
admin_account_user.update!(admin: true, member: false)

# Create member user (member only)
member_user = User.find_or_create_by!(email: "member@example.com") do |u|
  u.first_name = "Member"
  u.last_name = "User"
  u.password = "password"
  u.password_confirmation = "password"
  u.confirmed_at = Time.current
  u.terms_of_service = true
end
member_account_user = AccountUser.find_or_create_by!(user: member_user, account: account) do |au|
  au.admin = false
  au.member = true
end
member_account_user.update!(admin: false, member: true)

puts "Created users:"
puts "  - dev@example.com (system admin, account admin + member)"
puts "  - admin@example.com (account admin)"
puts "  - member@example.com (member)"
puts "All users have password: 'password'"
