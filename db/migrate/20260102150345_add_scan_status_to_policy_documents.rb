class AddScanStatusToPolicyDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :policy_documents, :scan_status, :integer, default: 0, null: false
    add_column :policy_documents, :last_scanned_at, :datetime
    add_column :policy_documents, :scan_error, :text
  end
end
