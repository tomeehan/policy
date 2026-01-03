class CreateSuggestedChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :suggested_changes do |t|
      t.references :issue, null: false, foreign_key: true
      t.text :original_text
      t.text :suggested_text, null: false
      t.integer :action_type, default: 0, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
