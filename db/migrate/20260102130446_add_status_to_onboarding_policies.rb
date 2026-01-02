class AddStatusToOnboardingPolicies < ActiveRecord::Migration[8.1]
  def change
    add_column :onboarding_policies, :status, :integer, default: 0, null: false
  end
end
