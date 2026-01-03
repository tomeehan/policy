class IssuePolicy < ApplicationPolicy
  def index?
    account_user.admin?
  end

  def show?
    account_user.admin? && record.account_id == account_user.account_id
  end

  def update?
    account_user.admin? && record.account_id == account_user.account_id
  end

  class Scope < Scope
    def resolve
      scope.where(account_id: account_user.account_id)
    end
  end
end
