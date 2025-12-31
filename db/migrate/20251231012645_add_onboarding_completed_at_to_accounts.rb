class AddOnboardingCompletedAtToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :onboarding_completed_at, :datetime
  end
end
