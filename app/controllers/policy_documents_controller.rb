class PolicyDocumentsController < ApplicationController
  before_action :authenticate_user!

  def index
    @policy_documents = current_account.policy_documents.order(:name)
  end
end
