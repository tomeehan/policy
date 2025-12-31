class AddContentToPolicyDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :policy_documents, :content, :text
  end
end
