class PolicyDocument < ApplicationRecord
  belongs_to :account
  has_many :issues, dependent: :destroy

  enum :scan_status, {idle: 0, scanning: 1, completed: 2, failed: 3}

  validates :name, presence: true

  def can_scan?
    !scanning?
  end

  def start_scan!
    return false if scanning?
    update!(scan_status: :scanning, scan_error: nil)
    true
  end

  def complete_scan!
    update!(scan_status: :completed, last_scanned_at: Time.current)
  end

  def fail_scan!(error_message)
    update!(scan_status: :failed, scan_error: error_message, last_scanned_at: Time.current)
  end
end
