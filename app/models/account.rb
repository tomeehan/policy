class Account < ApplicationRecord
  include Billing, Domains, Transfer, Types

  has_many :onboarding_policies, class_name: "Onboarding::Policy", dependent: :destroy
  has_many :policy_documents, dependent: :destroy

  def onboarding_completed?
    onboarding_completed_at.present?
  end
end
