module MarkdownHelper
  def render_markdown(content, strip_title: nil)
    return "" if content.blank?

    content = strip_leading_title(content, strip_title) if strip_title.present?

    Kramdown::Document.new(content).to_html.html_safe
  end

  private

  def strip_leading_title(content, title)
    # Remove leading H1 if it matches the title (case-insensitive, fuzzy match)
    content.sub(/\A#\s+#{Regexp.escape(title)}\s*\n+/i, "")
  end
end
