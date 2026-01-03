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
        action_type: suggestion[:action_type] || :replace_text
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
