class PolicyScanJob < ApplicationJob
  queue_as :default

  def perform(policy_document_id)
    @policy = PolicyDocument.find(policy_document_id)
    @errors = []

    broadcast_status("Checking spelling...")
    run_scanner(SpellingScanner)

    broadcast_status("Checking CQC compliance...")
    run_scanner(CqcComplianceScanner)

    broadcast_status("Checking for conflicts...")
    run_scanner(ConflictScanner)

    if @errors.any?
      @policy.fail_scan!(@errors.join("; "))
      broadcast_error("Scan completed with errors")
    else
      @policy.complete_scan!
      broadcast_complete
    end
  rescue => e
    Rails.logger.error "PolicyScanJob failed: #{e.message}"
    @policy.fail_scan!(e.message)
    broadcast_error("Scan failed: #{e.message}")
  end

  private

  def run_scanner(scanner_class)
    scanner_class.new(@policy).scan
  rescue => e
    @errors << "#{scanner_class.name}: #{e.message}"
    Rails.logger.error "#{scanner_class.name} failed: #{e.message}"
  end

  def broadcast_status(message)
    Turbo::StreamsChannel.broadcast_update_to(
      "policy_scan_#{@policy.id}",
      target: "scan-status",
      html: "<div class='flex items-center gap-2 text-gray-500'><svg class='animate-spin h-4 w-4' xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24'><circle class='opacity-25' cx='12' cy='12' r='10' stroke='currentColor' stroke-width='4'></circle><path class='opacity-75' fill='currentColor' d='M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z'></path></svg><span>#{message}</span></div>"
    )
  end

  def broadcast_complete
    Turbo::StreamsChannel.broadcast_update_to(
      "policy_scan_#{@policy.id}",
      target: "scan-status",
      html: "<p class='text-sm text-green-600'>Scan complete</p>"
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "policy_scan_#{@policy.id}",
      target: "issues-list",
      partial: "issues/list",
      locals: { policy_document: @policy, issues: @policy.issues.reload.open }
    )
  end

  def broadcast_error(message)
    Turbo::StreamsChannel.broadcast_update_to(
      "policy_scan_#{@policy.id}",
      target: "scan-status",
      html: "<p class='text-sm text-red-600'>#{message}</p>"
    )

    Turbo::StreamsChannel.broadcast_update_to(
      "policy_scan_#{@policy.id}",
      target: "issues-list",
      partial: "issues/list",
      locals: { policy_document: @policy, issues: @policy.issues.reload.open }
    )
  end
end
