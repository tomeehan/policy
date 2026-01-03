class IssueRelatedPolicy < ApplicationRecord
  belongs_to :issue
  belongs_to :policy_document
end
