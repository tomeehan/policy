class CreatePolicyDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :policy_documents do |t|
      t.string :name, null: false
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
  end
end
