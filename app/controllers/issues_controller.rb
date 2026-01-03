class IssuesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_policy_document
  before_action :set_issue, only: [:show, :update]

  def index
    @issues = @policy_document.issues.open.includes(:suggested_changes, :related_policies)
  end

  def show
  end

  def update
    if @issue.update(issue_params)
      respond_to do |format|
        format.html { redirect_to policy_document_path(@policy_document) }
        format.turbo_stream
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_policy_document
    @policy_document = current_account.policy_documents.find(params[:policy_document_id])
  end

  def set_issue
    @issue = current_account.issues.find_by!(id: params[:id], policy_document: @policy_document)
  end

  def issue_params
    params.require(:issue).permit(:status)
  end
end
