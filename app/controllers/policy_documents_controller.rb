class PolicyDocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_policy_document, only: [:show, :scan]

  def index
    @policy_documents = current_account.policy_documents.order(:name)
  end

  def show
  end

  def scan
    unless @policy_document.can_scan?
      respond_to do |format|
        format.html { redirect_to @policy_document, alert: "A scan is already in progress" }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("scan-status",
            html: "<p class='text-amber-600'>A scan is already in progress</p>")
        end
      end
      return
    end

    @policy_document.start_scan!
    @policy_document.issues.open.destroy_all

    PolicyScanJob.perform_later(@policy_document.id)

    respond_to do |format|
      format.html { redirect_to @policy_document, notice: "Scanning started..." }
      format.turbo_stream
    end
  end

  private

  def set_policy_document
    @policy_document = current_account.policy_documents.find(params[:id])
  end
end
