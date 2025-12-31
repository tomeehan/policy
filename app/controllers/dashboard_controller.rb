class DashboardController < ApplicationController
  before_action :redirect_to_onboarding_if_needed

  def show
  end

  private

  def redirect_to_onboarding_if_needed
    return unless user_signed_in?
    return if current_account.onboarding_completed?

    redirect_to onboarding_policies_path
  end
end
