class SuggestedChangePolicy < ApplicationPolicy
  def apply?
    record.issue.account_id.in?(user.user.accounts.ids)
  end

  def dismiss?
    apply?
  end
end
