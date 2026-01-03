class IssuePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    record.account_id.in?(user.user.accounts.ids)
  end

  def update?
    record.account_id.in?(user.user.accounts.ids)
  end

  class Scope < Scope
    def resolve
      scope.where(account: user.user.accounts)
    end
  end
end
