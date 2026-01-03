class SpellingScanner < BaseScanner
  def scan
    return if @policy.content.blank?

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {role: "system", content: system_prompt},
          {role: "user", content: @policy.content}
        ],
        response_format: {type: "json_object"}
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
          {original_text: s["original_text"], suggested_text: s["suggested_text"]}
        end
      )
    end
  rescue => e
    Rails.logger.error "SpellingScanner failed: #{e.message}"
    raise
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
