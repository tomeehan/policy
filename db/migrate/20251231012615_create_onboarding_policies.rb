class CreateOnboardingPolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_policies do |t|
      t.string :name, null: false
      t.references :account, null: false, foreign_key: true
      t.references :uploaded_by, null: false, foreign_key: {to_table: :account_users}

      t.timestamps
    end
  end
end
