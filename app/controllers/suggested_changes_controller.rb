class SuggestedChangesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_suggested_change

  def apply
    @suggested_change.apply!

    respond_to do |format|
      format.html { redirect_to policy_document_path(@policy_document) }
      format.turbo_stream
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to policy_document_path(@policy_document), alert: e.message }
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "suggested_change_#{@suggested_change.id}_error",
          html: "<p class='text-red-600 text-sm'>#{e.message}</p>"
        )
      end
    end
  end

  def dismiss
    @suggested_change.dismiss!

    respond_to do |format|
      format.html { redirect_to policy_document_path(@policy_document) }
      format.turbo_stream
    end
  end

  private

  def set_suggested_change
    @suggested_change = SuggestedChange.find(params[:id])
    @issue = current_account.issues.find(@suggested_change.issue_id)
    @policy_document = @issue.policy_document
  end
end
