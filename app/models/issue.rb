class Issue < ApplicationRecord
  belongs_to :account
  belongs_to :policy_document
  has_many :issue_related_policies, dependent: :destroy
  has_many :related_policies, through: :issue_related_policies, source: :policy_document
  has_many :suggested_changes, dependent: :destroy

  enum :issue_type, {conflict: 0, spelling: 1, cqc_compliance: 2}
  enum :status, {open: 0, resolved: 1, dismissed: 2}

  validates :description, presence: true
  validates :issue_type, presence: true

  scope :by_type, ->(type) { where(issue_type: type) }

  before_validation :set_account, on: :create

  def resolve_if_complete!
    return unless suggested_changes.reload.pending.empty?
    resolved!
  end

  private

  def set_account
    self.account ||= policy_document&.account
  end
end
