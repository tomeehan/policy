class CreateIssueRelatedPolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :issue_related_policies do |t|
      t.references :issue, null: false, foreign_key: true
      t.references :policy_document, null: false, foreign_key: true

      t.timestamps
    end

    add_index :issue_related_policies, [:issue_id, :policy_document_id], unique: true
  end
end
