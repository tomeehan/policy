module DiffHelper
  def diff_original(original, suggested)
    return "" if original.blank?
    diff = Diffy::SplitDiff.new(original, suggested, format: :html)
    style_diff_html(diff.left, :deletion).html_safe
  end

  def diff_suggested(original, suggested)
    return "" if suggested.blank?
    diff = Diffy::SplitDiff.new(original || "", suggested, format: :html)
    style_diff_html(diff.right, :insertion).html_safe
  end

  private

  def style_diff_html(html, type)
    case type
    when :deletion
      html.to_s.gsub("<del>", "<del class='bg-red-200 dark:bg-red-900/50 text-red-800 dark:text-red-200'>")
    when :insertion
      html.to_s.gsub("<ins>", "<ins class='bg-green-200 dark:bg-green-900/50 text-green-800 dark:text-green-200 no-underline'>")
    else
      html.to_s
    end
  end
end
