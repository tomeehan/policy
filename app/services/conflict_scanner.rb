class ConflictScanner < BaseScanner
  MAX_ITERATIONS = 50
  MAX_RETRIES = 5
  BASE_DELAY = 1 # seconds

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

      response = chat_with_retry(messages)

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
    raise
  end

  private

  def chat_with_retry(messages)
    retries = 0
    begin
      client.chat(
        parameters: {
          model: "gpt-4o",
          messages: messages,
          tools: tools,
          tool_choice: "auto"
        }
      )
    rescue Faraday::TooManyRequestsError, Faraday::Error => e
      raise unless rate_limit_error?(e)

      retries += 1
      if retries <= MAX_RETRIES
        delay = extract_retry_delay(e) || (BASE_DELAY * (2 ** (retries - 1)))
        Rails.logger.info "ConflictScanner rate limited, retrying in #{delay.round(1)}s (attempt #{retries}/#{MAX_RETRIES})"
        sleep(delay)
        retry
      else
        Rails.logger.error "ConflictScanner exceeded max retries after rate limiting"
        raise
      end
    end
  end

  def rate_limit_error?(error)
    error.is_a?(Faraday::TooManyRequestsError) || error.message.include?("429")
  end

  def extract_retry_delay(error)
    return nil unless error.response.is_a?(Hash)

    headers = error.response[:headers] || {}

    # Try Retry-After header first
    if headers["retry-after"]
      return headers["retry-after"].to_f
    end

    # Try x-ratelimit-reset-requests header (e.g., "1s", "2m30s")
    if headers["x-ratelimit-reset-requests"]
      return parse_reset_time(headers["x-ratelimit-reset-requests"])
    end

    nil
  rescue
    nil
  end

  def parse_reset_time(time_str)
    return nil unless time_str

    seconds = 0
    time_str.scan(/(\d+(?:\.\d+)?)([hms])/).each do |value, unit|
      case unit
      when "h" then seconds += value.to_f * 3600
      when "m" then seconds += value.to_f * 60
      when "s" then seconds += value.to_f
      end
    end

    seconds.positive? ? seconds : nil
  end

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
