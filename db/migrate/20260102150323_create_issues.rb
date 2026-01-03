class CreateIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :issues do |t|
      t.references :account, null: false, foreign_key: true
      t.references :policy_document, null: false, foreign_key: true
      t.integer :issue_type, null: false
      t.text :description, null: false
      t.text :excerpt
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :issues, [:account_id, :status]
    add_index :issues, [:policy_document_id, :status]
  end
end
