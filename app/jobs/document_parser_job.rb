class DocumentParserJob < ApplicationJob
  queue_as :default

  def perform(onboarding_policy_id)
    onboarding_policy = Onboarding::Policy.find(onboarding_policy_id)
    onboarding_policy.processing!

    result = ::DocumentParser.new(onboarding_policy.document).parse

    ActiveRecord::Base.transaction do
      onboarding_policy.account.policy_documents.create!(
        name: onboarding_policy.name,
        content: result&.content,
        published_at: result&.published_at
      )
      onboarding_policy.completed!
    end

    check_onboarding_completion(onboarding_policy.account)
  rescue => e
    Rails.logger.error "DocumentParserJob failed for #{onboarding_policy_id}: #{e.message}"
    onboarding_policy&.failed!
    raise e
  end

  private

  def check_onboarding_completion(account)
    return unless account.onboarding_policies.where.not(status: :completed).empty?

    account.update!(onboarding_completed_at: Time.current)

    Turbo::StreamsChannel.broadcast_update_to(
      "onboarding_progress_#{account.id}",
      target: "onboarding-progress",
      partial: "onboarding/policies/progress_complete",
      locals: { account: account }
    )
  end
end
