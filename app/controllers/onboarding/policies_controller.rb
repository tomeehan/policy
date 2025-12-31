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
    current_account.update!(onboarding_completed_at: Time.current)
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
end
