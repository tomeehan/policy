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
    current_account.onboarding_policies.pending.find_each do |onboarding_policy|
      DocumentParserJob.perform_later(onboarding_policy.id)
    end
    redirect_to progress_onboarding_policies_path
  end

  def progress
    @total = current_account.onboarding_policies.count
    @completed = current_account.onboarding_policies.completed.count
    @all_done = current_account.onboarding_completed?
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
end
