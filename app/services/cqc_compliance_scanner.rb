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
          {role: "system", content: system_prompt},
          {role: "user", content: "Policy: #{@policy.name}\n\n#{@policy.content}"}
        ],
        response_format: {type: "json_object"}
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
            action_type: s["action_type"] || "replace_text"
          }
        end
      )
    end
  rescue => e
    Rails.logger.error "CqcComplianceScanner failed: #{e.message}"
    raise
  end

  private

  def system_prompt
    <<~PROMPT
      You are a CQC compliance expert reviewing care policies for health and social care providers in England.

      #{CQC_CONTEXT}

      IMPORTANT CONTEXT ABOUT POLICY SCOPE:
      - Each document is ONE policy (e.g. Appraisal, Safeguarding, Medication, Complaints).
      - Organisations will also have OTHER policies covering topics like safeguarding, incident reporting, and complaints.
      - Do NOT criticise a policy for omitting topics that are clearly outside its scope.
        For example, an "Appraisal Policy" is not expected to contain a full incident-reporting procedure.

      YOUR TASK:
      - First, infer the intended scope from the policy name and content.
      - Within that scope, check if the policy:
        - Clearly describes the process and responsibilities.
        - Aligns with current CQC expectations for that area.
        - Avoids obviously unsafe or non-compliant practices.
      - Only flag issues that represent a genuine risk of non-compliance or confusion, not "nice to have" detail.

      OUTPUT FORMAT:
      Return JSON in this format:
      {
        "overall_assessment": "compliant|minor_improvements|major_issues",
        "issues": [
          {
            "description": "Clear explanation of the compliance issue and why it matters",
            "cqc_domain": "Safe|Effective|Caring|Responsive|Well-led",
            "requirement_reference": "Short phrase, e.g. 'Staff training for appraisals'",
            "severity": "high|medium|low",
            "excerpt": "The relevant section from the policy (or describe what's missing)",
            "suggestions": [
              {
                "action_type": "replace_text|insert_text|delete_text",
                "original_text": "text to replace or delete (null for insert)",
                "suggested_text": "replacement text or new content to add"
              }
            ]
          }
        ]
      }

      RULES:
      - It is acceptable for a focused policy (like an Appraisal Policy) to be short if the process is clear.
      - Do NOT invent issues just to have something to say.
      - If the policy is reasonable and appropriately scoped, set "overall_assessment" to "compliant" and return "issues": [].
      - Only include issues where:
        - The omission or wording could realistically cause CQC concern OR
        - It conflicts with CQC expectations for that type of policy.
      - Be specific about which CQC requirement is affected using "cqc_domain" and "requirement_reference".
      - Use "insert_text" when content is missing entirely.

      You are providing drafting assistance only. Do NOT describe your output as legal advice or a formal CQC judgment.
    PROMPT
  end
end
