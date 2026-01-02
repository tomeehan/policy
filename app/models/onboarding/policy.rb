class Onboarding::Policy < ApplicationRecord
  belongs_to :account
  belongs_to :uploaded_by, class_name: "AccountUser"

  has_one_attached :document

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  validates :name, presence: true
  validates :document, presence: true

  after_update_commit :broadcast_progress, if: :saved_change_to_status?

  private

  def broadcast_progress
    Turbo::StreamsChannel.broadcast_update_to(
      "onboarding_progress_#{account_id}",
      target: "onboarding-progress",
      partial: "onboarding/policies/progress",
      locals: { account: account }
    )
  end
end
