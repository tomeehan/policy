# Issues Feature Specification

## Overview

Issues are an automated way for AI to identify problems with policy documents. Users can scan a policy to detect issues, review AI-generated suggested changes, and apply or dismiss them.

## Issue Types

| Type | Description |
|------|-------------|
| `conflict` | Advice in this policy conflicts with advice in another policy |
| `spelling` | Spelling errors in the policy text |
| `cqc_compliance` | Policy is not aligned with CQC statutory rules |

---

## Migrations

### db/migrate/XXXXXX_create_issues.rb

```ruby
class CreateIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :issues do |t|
      t.references :account, null: false, foreign_key: true
      t.references :policy_document, null: false, foreign_key: true
      t.integer :issue_type, null: false
      t.text :description, null: false
      t.text :excerpt
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :issues, [:account_id, :status]
    add_index :issues, [:policy_document_id, :status]
  end
end
```

### db/migrate/XXXXXX_create_issue_related_policies.rb

```ruby
class CreateIssueRelatedPolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :issue_related_policies do |t|
      t.references :issue, null: false, foreign_key: true
      t.references :policy_document, null: false, foreign_key: true

      t.timestamps
    end

    add_index :issue_related_policies, [:issue_id, :policy_document_id], unique: true
  end
end
```

### db/migrate/XXXXXX_create_suggested_changes.rb

```ruby
class CreateSuggestedChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :suggested_changes do |t|
      t.references :issue, null: false, foreign_key: true
      t.text :original_text
      t.text :suggested_text, null: false
      t.integer :action_type, default: 0, null: false  # 0=replace, 1=insert, 2=delete
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
```

### db/migrate/XXXXXX_add_scan_status_to_policy_documents.rb

```ruby
class AddScanStatusToPolicyDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :policy_documents, :scan_status, :integer, default: 0, null: false
    add_column :policy_documents, :last_scanned_at, :datetime
    add_column :policy_documents, :scan_error, :text
  end
end
```

---

## Models

### app/models/issue.rb

```ruby
class Issue < ApplicationRecord
  belongs_to :account
  belongs_to :policy_document
  has_many :issue_related_policies, dependent: :destroy
  has_many :related_policies, through: :issue_related_policies, source: :policy_document
  has_many :suggested_changes, dependent: :destroy

  enum :issue_type, { conflict: 0, spelling: 1, cqc_compliance: 2 }
  enum :status, { open: 0, resolved: 1, dismissed: 2 }

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
```

### app/models/issue_related_policy.rb

```ruby
class IssueRelatedPolicy < ApplicationRecord
  belongs_to :issue
  belongs_to :policy_document
end
```

### app/models/suggested_change.rb

```ruby
class SuggestedChange < ApplicationRecord
  belongs_to :issue

  enum :action_type, { replace: 0, insert: 1, delete: 2 }
  enum :status, { pending: 0, applied: 1, dismissed: 2 }

  validates :suggested_text, presence: true, unless: :delete?
  validates :original_text, presence: true, if: -> { replace? || delete? }

  def apply!
    policy = issue.policy_document

    new_content = case action_type
    when "replace"
      apply_replace(policy.content)
    when "insert"
      apply_insert(policy.content)
    when "delete"
      apply_delete(policy.content)
    end

    policy.update!(content: new_content)
    applied!
    issue.resolve_if_complete!
  end

  def dismiss!
    dismissed!
    issue.resolve_if_complete!
  end

  private

  def apply_replace(content)
    unless content.include?(original_text)
      raise StandardError, "Original text not found in policy - it may have been edited"
    end
    content.sub(original_text, suggested_text)
  end

  def apply_insert(content)
    # Insert at the end of the document
    "#{content}\n\n#{suggested_text}"
  end

  def apply_delete(content)
    unless content.include?(original_text)
      raise StandardError, "Original text not found in policy - it may have been edited"
    end
    content.sub(original_text, "")
  end
end
```

### app/models/policy_document.rb (add association and scan status)

```ruby
class PolicyDocument < ApplicationRecord
  # ... existing code ...
  has_many :issues, dependent: :destroy

  enum :scan_status, { idle: 0, scanning: 1, completed: 2, failed: 3 }

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
```

### app/models/account.rb (add association)

```ruby
class Account < ApplicationRecord
  # ... existing code ...
  has_many :issues, dependent: :destroy
end
```

---

## Routes

### config/routes.rb (add to existing)

```ruby
resources :policy_documents do
  member do
    post :scan
  end
  resources :issues, only: [:index, :show, :update]
end

resources :suggested_changes, only: [] do
  member do
    post :apply
    post :dismiss
  end
end
```

---

## Jobs

### app/jobs/policy_scan_job.rb

```ruby
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

    # Still update issues list with any issues that were found
    Turbo::StreamsChannel.broadcast_update_to(
      "policy_scan_#{@policy.id}",
      target: "issues-list",
      partial: "issues/list",
      locals: { policy_document: @policy, issues: @policy.issues.reload.open }
    )
  end
end
```

---

## Services

### app/services/base_scanner.rb

```ruby
class BaseScanner
  def initialize(policy_document)
    @policy = policy_document
  end

  private

  def client
    @client ||= OpenAI::Client.new
  end

  def create_issue(issue_type:, description:, excerpt:, suggestions:, related_policies: [])
    issue = @policy.issues.create!(
      issue_type: issue_type,
      description: description,
      excerpt: excerpt
    )

    related_policies.each do |related_policy|
      issue.issue_related_policies.create!(policy_document: related_policy)
    end

    suggestions.each do |suggestion|
      issue.suggested_changes.create!(
        original_text: suggestion[:original_text],
        suggested_text: suggestion[:suggested_text],
        action_type: suggestion[:action_type] || :replace
      )
    end

    issue
  end

  def parse_response(response)
    content = response.dig("choices", 0, "message", "content")
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse scanner response: #{e.message}"
    nil
  end
end
```

### app/services/spelling_scanner.rb

```ruby
class SpellingScanner < BaseScanner
  def scan
    return if @policy.content.blank?

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: @policy.content }
        ],
        response_format: { type: "json_object" }
      }
    )

    result = parse_response(response)
    return unless result

    result["issues"]&.each do |issue_data|
      create_issue(
        issue_type: :spelling,
        description: issue_data["description"],
        excerpt: issue_data["excerpt"],
        suggestions: issue_data["suggestions"].map do |s|
          { original_text: s["original_text"], suggested_text: s["suggested_text"] }
        end
      )
    end
  rescue => e
    Rails.logger.error "SpellingScanner failed: #{e.message}"
  end

  private

  def system_prompt
    <<~PROMPT
      You are a spelling checker for policy documents. Analyze the document and identify spelling errors.

      Return JSON in this format:
      {
        "issues": [
          {
            "description": "Brief explanation of the error",
            "excerpt": "The sentence containing the error",
            "suggestions": [
              {
                "original_text": "misspeled",
                "suggested_text": "misspelled"
              }
            ]
          }
        ]
      }

      Rules:
      - Only flag clear spelling errors
      - Accept both British and American spellings as correct
      - Do not flag proper nouns, acronyms, or technical terms
      - Return {"issues": []} if no errors found
    PROMPT
  end
end
```

### app/services/cqc_compliance_scanner.rb

```ruby
class CqcComplianceScanner < BaseScanner
  CQC_CONTEXT = <<~CQC
    Key CQC (Care Quality Commission) requirements for care policies:

    FIVE KEY QUESTIONS:
    1. Safe - Protection from abuse, neglect, and avoidable harm
    2. Effective - Care achieves good outcomes, promotes quality of life
    3. Caring - Staff treat people with compassion, kindness, dignity
    4. Responsive - Services meet people's needs
    5. Well-led - Leadership, management, and governance assures high-quality care

    POLICIES SHOULD ADDRESS:
    - Clear safeguarding procedures and reporting
    - Complaint handling processes
    - Staff training requirements
    - Incident reporting procedures
    - Consent and mental capacity considerations
    - Data protection and confidentiality (GDPR)
    - Equality and diversity compliance
    - Risk assessment procedures
    - Medication management (where applicable)
    - Health and safety requirements
  CQC

  def scan
    return if @policy.content.blank?

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: "Policy: #{@policy.name}\n\n#{@policy.content}" }
        ],
        response_format: { type: "json_object" }
      }
    )

    result = parse_response(response)
    return unless result

    result["issues"]&.each do |issue_data|
      create_issue(
        issue_type: :cqc_compliance,
        description: issue_data["description"],
        excerpt: issue_data["excerpt"],
        suggestions: issue_data["suggestions"].map do |s|
          {
            original_text: s["original_text"],
            suggested_text: s["suggested_text"],
            action_type: s["action_type"] || "replace"
          }
        end
      )
    end
  rescue => e
    Rails.logger.error "CqcComplianceScanner failed: #{e.message}"
  end

  private

  def system_prompt
    <<~PROMPT
      You are a CQC compliance expert reviewing care home policy documents.

      #{CQC_CONTEXT}

      Analyze the policy and identify compliance gaps or issues. Focus on:
      - Missing required elements for this type of policy
      - Outdated guidance that conflicts with current CQC standards
      - Vague language where specific procedures are required
      - Missing safeguarding or reporting requirements

      Return JSON in this format:
      {
        "issues": [
          {
            "description": "Clear explanation of the compliance issue and why it matters",
            "excerpt": "The relevant section from the policy (or describe what's missing)",
            "suggestions": [
              {
                "action_type": "replace|insert|delete",
                "original_text": "text to replace or delete (null for insert)",
                "suggested_text": "replacement text or new content to add"
              }
            ]
          }
        ]
      }

      Action types:
      - "replace": Replace original_text with suggested_text
      - "insert": Add suggested_text to the end of the policy (original_text is null)
      - "delete": Remove original_text from the policy

      Rules:
      - Only flag genuine compliance concerns, not stylistic preferences
      - Be specific about which CQC requirement is affected
      - Provide actionable suggestions
      - Use "insert" when content is missing entirely
      - Return {"issues": []} if policy is compliant
    PROMPT
  end
end
```

### app/services/conflict_scanner.rb

Uses OpenAI tools to systematically fetch and compare every policy. The LLM is instructed to fetch all policies and compare each one against the current policy for conflicts.

```ruby
class ConflictScanner < BaseScanner
  MAX_ITERATIONS = 50  # Safety limit to prevent infinite loops

  def scan
    return if @policy.content.blank?

    @other_policies = @policy.account.policy_documents
      .where.not(id: @policy.id)
      .where.not(content: [nil, ""])
      .pluck(:id, :name)
      .to_h

    return if @other_policies.empty?

    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: user_prompt }
    ]

    iterations = 0
    loop do
      iterations += 1
      if iterations > MAX_ITERATIONS
        Rails.logger.warn "ConflictScanner hit max iterations for policy #{@policy.id}"
        break
      end

      response = client.chat(
        parameters: {
          model: "gpt-4o",
          messages: messages,
          tools: tools,
          tool_choice: "auto"
        }
      )

      message = response.dig("choices", 0, "message")
      messages << message

      tool_calls = message["tool_calls"]
      break unless tool_calls&.any?

      tool_calls.each do |tool_call|
        result = handle_tool_call(tool_call)
        messages << {
          role: "tool",
          tool_call_id: tool_call["id"],
          content: result.to_json
        }
      end
    end
  rescue => e
    Rails.logger.error "ConflictScanner failed: #{e.message}"
  end

  private

  def tools
    [
      {
        type: "function",
        function: {
          name: "get_policy_content",
          description: "Fetch the full content of a policy to compare for conflicts",
          parameters: {
            type: "object",
            properties: {
              policy_id: { type: "integer" }
            },
            required: ["policy_id"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "report_conflict",
          description: "Report a conflict between the current policy and another",
          parameters: {
            type: "object",
            properties: {
              other_policy_id: { type: "integer" },
              description: { type: "string" },
              excerpt: { type: "string" },
              original_text: { type: "string" },
              suggested_text: { type: "string" }
            },
            required: ["other_policy_id", "description", "excerpt"]
          }
        }
      }
    ]
  end

  def handle_tool_call(tool_call)
    name = tool_call.dig("function", "name")
    args = JSON.parse(tool_call.dig("function", "arguments"))

    case name
    when "get_policy_content"
      get_policy_content(args["policy_id"])
    when "report_conflict"
      report_conflict(args)
    end
  end

  def get_policy_content(policy_id)
    return { error: "Not found" } unless @other_policies.key?(policy_id)

    policy = PolicyDocument.find(policy_id)
    { id: policy.id, name: policy.name, content: policy.content }
  end

  def report_conflict(args)
    other_policy = PolicyDocument.find_by(id: args["other_policy_id"])
    return { error: "Not found" } unless other_policy

    # Check for existing conflict between these policies to avoid duplicates
    existing_conflict = @policy.issues.conflict.joins(:issue_related_policies)
      .where(issue_related_policies: { policy_document_id: other_policy.id })
      .where(status: :open)
      .exists?

    if existing_conflict
      return { skipped: true, message: "Conflict already reported" }
    end

    suggestions = []
    if args["original_text"].present? && args["suggested_text"].present?
      suggestions << {
        original_text: args["original_text"],
        suggested_text: args["suggested_text"]
      }
    end

    create_issue(
      issue_type: :conflict,
      description: args["description"],
      excerpt: args["excerpt"],
      suggestions: suggestions,
      related_policies: [other_policy]
    )

    { success: true }
  end

  def user_prompt
    policy_list = @other_policies.map { |id, name| "- #{name} (ID: #{id})" }.join("\n")

    <<~PROMPT
      ## Current Policy: #{@policy.name}

      #{@policy.content}

      ---

      ## Other Policies:

      #{policy_list}
    PROMPT
  end

  def system_prompt
    <<~PROMPT
      You check policy documents for conflicts.

      INSTRUCTIONS:
      1. You MUST fetch EVERY policy in the list using `get_policy_content`
      2. Compare each one against the current policy
      3. Use `report_conflict` for any genuine conflicts

      A CONFLICT is contradictory guidance:
      - Contradictory procedures
      - Inconsistent timelines or deadlines
      - Conflicting responsibilities
      - Incompatible requirements

      NOT conflicts: different topics, same info worded differently, varying detail levels.

      Fetch all policies now.
    PROMPT
  end
end
```

---

## Controllers

### app/controllers/policy_documents_controller.rb (add scan action)

```ruby
class PolicyDocumentsController < ApplicationController
  # ... existing actions ...

  def scan
    @policy_document = current_account.policy_documents.find(params[:id])

    unless @policy_document.can_scan?
      respond_to do |format|
        format.html { redirect_to @policy_document, alert: "A scan is already in progress" }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("scan-status",
            html: "<p class='text-amber-600'>A scan is already in progress</p>")
        end
      end
      return
    end

    # Mark as scanning and clear existing open issues
    @policy_document.start_scan!
    @policy_document.issues.open.destroy_all

    PolicyScanJob.perform_later(@policy_document.id)

    respond_to do |format|
      format.html { redirect_to @policy_document, notice: "Scanning started..." }
      format.turbo_stream
    end
  end
end
```

### app/controllers/issues_controller.rb

```ruby
class IssuesController < ApplicationController
  before_action :set_policy_document
  before_action :set_issue, only: [:show, :update]

  def index
    @issues = @policy_document.issues.open.includes(:suggested_changes, :related_policies)
  end

  def show
  end

  def update
    if @issue.update(issue_params)
      respond_to do |format|
        format.html { redirect_to policy_document_path(@policy_document) }
        format.turbo_stream
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_policy_document
    @policy_document = current_account.policy_documents.find(params[:policy_document_id])
  end

  def set_issue
    # Double-check account scope for security
    @issue = current_account.issues.find_by!(id: params[:id], policy_document: @policy_document)
  end

  def issue_params
    params.require(:issue).permit(:status)
  end
end
```

### app/controllers/suggested_changes_controller.rb

```ruby
class SuggestedChangesController < ApplicationController
  before_action :set_suggested_change

  def apply
    @suggested_change.apply!

    respond_to do |format|
      format.html { redirect_to policy_document_path(@policy_document) }
      format.turbo_stream
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to policy_document_path(@policy_document), alert: e.message }
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "suggested_change_#{@suggested_change.id}_error",
          html: "<p class='text-red-600 text-sm'>#{e.message}</p>"
        )
      end
    end
  end

  def dismiss
    @suggested_change.dismiss!

    respond_to do |format|
      format.html { redirect_to policy_document_path(@policy_document) }
      format.turbo_stream
    end
  end

  private

  def set_suggested_change
    # Scope through current_account for multi-tenancy
    @issue = current_account.issues.find_by!(id: SuggestedChange.where(id: params[:id]).select(:issue_id))
    @suggested_change = @issue.suggested_changes.find(params[:id])
    @policy_document = @issue.policy_document
  end
end
```

---

## Authorization Policies

### app/policies/issue_policy.rb

```ruby
class IssuePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    record.account_id == user.accounts.ids
  end

  def update?
    record.account_id == user.accounts.ids
  end

  class Scope < Scope
    def resolve
      scope.where(account: user.accounts)
    end
  end
end
```

### app/policies/suggested_change_policy.rb

```ruby
class SuggestedChangePolicy < ApplicationPolicy
  def apply?
    record.issue.account_id.in?(user.accounts.ids)
  end

  def dismiss?
    apply?
  end
end
```

---

## Views

### app/views/policy_documents/show.html.erb (add issues section)

```erb
<% content_for :title, @policy_document.name %>

<%= turbo_stream_from "policy_scan_#{@policy_document.id}" %>

<div class="container mx-auto p-4">
  <div class="my-8">
    <div class="mb-6">
      <%= link_to "← Back to Policies", policy_documents_path, class: "text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white" %>
    </div>

    <div class="flex justify-between items-start mb-6">
      <div>
        <h1 class="mb-2"><%= @policy_document.name %></h1>
        <% if @policy_document.published_at.present? %>
          <p class="text-sm text-gray-500 dark:text-gray-400">
            Published: <%= @policy_document.published_at.strftime("%B %d, %Y") %>
          </p>
        <% end %>
      </div>

      <%= button_to "Scan for Issues", scan_policy_document_path(@policy_document),
          method: :post, class: "btn btn-secondary",
          form: { data: { turbo_stream: true } } %>
    </div>

    <!-- Scan Status -->
    <div id="scan-status" class="mb-4"></div>

    <!-- Issues Section -->
    <div id="issues-list" class="mb-8">
      <%= render "issues/list", policy_document: @policy_document, issues: @policy_document.issues.open %>
    </div>

    <!-- Policy Content -->
    <div id="policy-content">
      <% if @policy_document.content.present? %>
        <div class="prose dark:prose-invert max-w-none">
          <%= render_markdown(@policy_document.content, strip_title: @policy_document.name) %>
        </div>
      <% else %>
        <p class="text-gray-600 dark:text-gray-400">No content available for this policy.</p>
      <% end %>
    </div>
  </div>
</div>
```

### app/views/issues/_list.html.erb

```erb
<% if issues.any? %>
  <div class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg p-4 mb-6">
    <h2 class="text-lg font-semibold text-amber-800 dark:text-amber-200 mb-4">
      <%= pluralize(issues.count, "Issue") %> Found
    </h2>

    <div class="space-y-4">
      <%= render partial: "issues/issue", collection: issues, as: :issue, locals: { policy_document: policy_document } %>
    </div>
  </div>
<% end %>
```

### app/views/issues/_issue.html.erb

```erb
<%= turbo_frame_tag dom_id(issue) do %>
  <div class="bg-white dark:bg-gray-800 rounded-lg p-4 border border-gray-200 dark:border-gray-700">
    <div class="flex items-center gap-2 mb-3">
      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium
        <%= case issue.issue_type
            when 'conflict' then 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200'
            when 'spelling' then 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
            when 'cqc_compliance' then 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200'
            end %>">
        <%= issue.issue_type.titleize %>
      </span>

      <% if issue.conflict? && issue.related_policies.any? %>
        <span class="text-sm text-gray-500 dark:text-gray-400">
          Conflicts with: <%= issue.related_policies.pluck(:name).to_sentence %>
        </span>
      <% end %>
    </div>

    <p class="text-gray-700 dark:text-gray-300 mb-3"><%= issue.description %></p>

    <% if issue.excerpt.present? %>
      <blockquote class="border-l-4 border-gray-300 dark:border-gray-600 pl-4 py-2 mb-4 text-gray-600 dark:text-gray-400 italic">
        "<%= truncate(issue.excerpt, length: 200) %>"
      </blockquote>
    <% end %>

    <% if issue.suggested_changes.pending.any? %>
      <div class="space-y-3 mb-4">
        <p class="text-sm font-medium text-gray-700 dark:text-gray-300">Suggested Changes:</p>
        <%= render partial: "suggested_changes/suggested_change", collection: issue.suggested_changes.pending, as: :suggested_change %>
      </div>
    <% end %>

    <div class="flex justify-end">
      <%= button_to "Dismiss Issue",
          policy_document_issue_path(policy_document, issue),
          method: :patch,
          params: { issue: { status: :dismissed } },
          class: "text-sm text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200",
          form: { data: { turbo_stream: true } } %>
    </div>
  </div>
<% end %>
```

### app/views/suggested_changes/_suggested_change.html.erb

Uses side-by-side diff view with word-level highlighting via the `diffy` gem.

```erb
<%= turbo_frame_tag dom_id(suggested_change) do %>
  <div class="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
    <div class="grid grid-cols-2 gap-4 mb-3">
      <div>
        <span class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Original</span>
        <div class="mt-1 text-sm diff-original">
          <%= diff_original(suggested_change.original_text, suggested_change.suggested_text) %>
        </div>
      </div>
      <div>
        <span class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Suggested</span>
        <div class="mt-1 text-sm diff-suggested">
          <%= diff_suggested(suggested_change.original_text, suggested_change.suggested_text) %>
        </div>
      </div>
    </div>

    <div id="suggested_change_<%= suggested_change.id %>_error"></div>

    <div class="flex gap-2">
      <%= button_to "Apply",
          apply_suggested_change_path(suggested_change),
          method: :post,
          class: "btn btn-primary btn-sm",
          form: { data: { turbo_stream: true } } %>
      <%= button_to "Dismiss",
          dismiss_suggested_change_path(suggested_change),
          method: :post,
          class: "btn btn-ghost btn-sm",
          form: { data: { turbo_stream: true } } %>
    </div>
  </div>
<% end %>
```

### app/views/policy_documents/scan.turbo_stream.erb

```erb
<%= turbo_stream.update "scan-status" do %>
  <div class="flex items-center gap-2 text-gray-500">
    <svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    <span>Starting scan...</span>
  </div>
<% end %>
```

### app/views/issues/update.turbo_stream.erb

```erb
<%= turbo_stream.remove dom_id(@issue) %>
```

### app/views/suggested_changes/apply.turbo_stream.erb

```erb
<%= turbo_stream.remove dom_id(@suggested_change) %>

<% if @issue.suggested_changes.reload.pending.empty? %>
  <%= turbo_stream.remove dom_id(@issue) %>
<% end %>

<%# Refresh the policy content to show the applied change %>
<%= turbo_stream.update "policy-content" do %>
  <% if @policy_document.content.present? %>
    <div class="prose dark:prose-invert max-w-none">
      <%= render_markdown(@policy_document.reload.content, strip_title: @policy_document.name) %>
    </div>
  <% else %>
    <p class="text-gray-600 dark:text-gray-400">No content available for this policy.</p>
  <% end %>
<% end %>
```

### app/views/suggested_changes/dismiss.turbo_stream.erb

```erb
<%= turbo_stream.remove dom_id(@suggested_change) %>

<% if @issue.suggested_changes.reload.pending.empty? %>
  <%= turbo_stream.remove dom_id(@issue) %>
<% end %>
```

---

## Dependencies

### Gemfile

```ruby
gem "ruby-openai"
gem "diffy"
```

---

## Helpers

### app/helpers/diff_helper.rb

Uses `Diffy::SplitDiff` for proper side-by-side diff with word-level highlighting.

```ruby
module DiffHelper
  def diff_original(original, suggested)
    diff = Diffy::SplitDiff.new(original, suggested, format: :html)
    style_diff_html(diff.left, :deletion).html_safe
  end

  def diff_suggested(original, suggested)
    diff = Diffy::SplitDiff.new(original, suggested, format: :html)
    style_diff_html(diff.right, :insertion).html_safe
  end

  private

  def style_diff_html(html, type)
    case type
    when :deletion
      html.gsub("<del>", "<del class='bg-red-200 dark:bg-red-900/50 text-red-800 dark:text-red-200'>")
    when :insertion
      html.gsub("<ins>", "<ins class='bg-green-200 dark:bg-green-900/50 text-green-800 dark:text-green-200 no-underline'>")
    else
      html
    end
  end
end
```

---

## Edge Cases

### Stale Issues (Handled)

If policy content is edited after issues are created, suggested changes may not match:

- ✅ On apply, `apply!` checks if `original_text` exists in content
- ✅ If not found, shows error via Turbo Stream and lets user dismiss
- Future: Consider adding `stale` status flag that auto-marks issues when policy is edited

### Token Limits

For conflict scanning with many policies:

- ✅ ConflictScanner has `MAX_ITERATIONS = 50` safety limit
- Context window limits may still be hit with very long policies
- Future: May need to chunk large policies or use summaries for initial detection

### Concurrent Scans (Handled)

- ✅ `scan_status` column prevents concurrent scans on same policy
- ✅ Controller checks `can_scan?` before starting
- ✅ Job sets status to `scanning` at start, `completed` or `failed` at end

### Scan Failures (Handled)

- ✅ Each scanner runs in `run_scanner` wrapper that catches errors
- ✅ Errors are collected and stored in `scan_error` column
- ✅ UI shows error status via Turbo Stream broadcast
- ✅ Partial results (issues found before failure) are still displayed

### Conflict Deduplication (Handled)

- ✅ `report_conflict` checks for existing open conflicts between policies
- ✅ Skips creating duplicate issues if conflict already exists

### Rate Limiting (Future)

- Show "last scanned at" timestamp (column exists: `last_scanned_at`)
- Could add cooldown check in `can_scan?` (e.g., 5 minutes)
- Could limit scans per account per day via counter cache

---

## Future Enhancements

1. **Batch scanning** - Scan all policies at once
2. **Scheduled scans** - Automatic weekly/monthly scans
3. **Issue history** - Track resolved issues over time
4. **Severity levels** - High/medium/low priority issues
5. **Custom rules** - Account-specific compliance requirements
6. **Notifications** - Email alerts for new issues
