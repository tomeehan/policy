class PolicyDocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_policy_document, only: [:show]

  def index
    @policy_documents = current_account.policy_documents.order(:name)
  end

  def show
  end

  private

  def set_policy_document
    @policy_document = current_account.policy_documents.find(params[:id])
  end
end
