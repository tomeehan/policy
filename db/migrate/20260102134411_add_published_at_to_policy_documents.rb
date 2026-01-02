class AddPublishedAtToPolicyDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :policy_documents, :published_at, :date
  end
end
