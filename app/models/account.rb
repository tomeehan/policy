class Account < ApplicationRecord
  include Billing, Domains, Transfer, Types

  has_many :onboarding_policies, class_name: "Onboarding::Policy", dependent: :destroy

  def onboarding_completed?
    onboarding_completed_at.present?
  end
end
