class SuggestedChange < ApplicationRecord
  belongs_to :issue

  enum :action_type, {replace_text: 0, insert_text: 1, delete_text: 2}
  enum :status, {pending: 0, applied: 1, dismissed: 2}

  validates :suggested_text, presence: true, unless: :delete_text?
  validates :original_text, presence: true, if: -> { replace_text? || delete_text? }

  def apply!
    policy = issue.policy_document

    new_content = case action_type
    when "replace_text"
      apply_replace(policy.content)
    when "insert_text"
      apply_insert(policy.content)
    when "delete_text"
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
    "#{content}\n\n#{suggested_text}"
  end

  def apply_delete(content)
    unless content.include?(original_text)
      raise StandardError, "Original text not found in policy - it may have been edited"
    end
    content.sub(original_text, "")
  end
end
