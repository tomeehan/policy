class Onboarding::Policy < ApplicationRecord
  belongs_to :account
  belongs_to :uploaded_by, class_name: "AccountUser"

  has_one_attached :document

  validates :name, presence: true
  validates :document, presence: true
end
