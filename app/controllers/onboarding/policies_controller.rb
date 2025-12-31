class Onboarding::PoliciesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_policy, only: [:update, :destroy]

  def index
    @policies = current_account.onboarding_policies.includes(:document_attachment)
  end

  def create
    @policy = current_account.onboarding_policies.new(policy_params)
    @policy.uploaded_by = current_account_user

    if @policy.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to onboarding_policies_path }
      end
    else
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @policy.update(policy_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to onboarding_policies_path }
      end
    else
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @policy.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to onboarding_policies_path }
    end
  end

  def complete
    ActiveRecord::Base.transaction do
      current_account.onboarding_policies.find_each do |onboarding_policy|
        content = parse_document_content(onboarding_policy)
        current_account.policy_documents.create!(name: onboarding_policy.name, content: content)
      end
      current_account.update!(onboarding_completed_at: Time.current)
    end
    redirect_to root_path, notice: "Welcome to Policy Pro!"
  end

  private

  def set_policy
    @policy = current_account.onboarding_policies.find(params[:id])
  end

  def policy_params
    params.require(:onboarding_policy).permit(:name, :document)
  end

  def current_account_user
    current_account.account_users.find_by(user: current_user)
  end

  def parse_document_content(onboarding_policy)
    return nil unless onboarding_policy.document.attached?

    content_type = onboarding_policy.document.content_type
    return nil unless word_document?(content_type)

    onboarding_policy.document.open do |file|
      PandocRuby.docx(file.path).to_markdown
    end
  rescue => e
    Rails.logger.error "Failed to parse document: #{e.message}"
    nil
  end

  def word_document?(content_type)
    content_type.in?([
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "application/msword"
    ])
  end
end
