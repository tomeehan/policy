class DocumentParser
  WORD_CONTENT_TYPES = [
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/msword"
  ].freeze

  PDF_CONTENT_TYPE = "application/pdf"

  def initialize(attachment)
    @attachment = attachment
  end

  Result = Struct.new(:content, :published_at, keyword_init: true)

  def parse
    return nil unless @attachment.attached?

    content = @attachment.open do |file|
      case @attachment.content_type
      when *WORD_CONTENT_TYPES
        parse_word_document(file)
      when PDF_CONTENT_TYPE
        parse_pdf_document(file)
      end
    end

    return nil if content.blank?

    sanitize_and_extract(content)
  rescue => e
    Rails.logger.error "DocumentParser failed: #{e.message}"
    nil
  end

  private

  def parse_word_document(file)
    stdout, stderr, status = Open3.capture3("pandoc", "-f", "docx", "-t", "markdown", file.path)
    if status.success?
      stdout
    else
      Rails.logger.error "Pandoc conversion failed: #{stderr}"
      nil
    end
  end

  def parse_pdf_document(file)
    Dir.mktmpdir do |tmpdir|
      stdout, stderr, status = Open3.capture3(
        "pdftoppm", "-png", "-r", "150", file.path, "#{tmpdir}/page"
      )
      unless status.success?
        Rails.logger.error "PDF to image conversion failed: #{stderr}"
        return nil
      end

      page_images = Dir.glob("#{tmpdir}/page-*.png").sort
      return nil if page_images.empty?

      extract_text_with_openai(page_images)
    end
  end

  def extract_text_with_openai(image_paths)
    client = OpenAI::Client.new

    content = [
      {
        type: "text",
        text: "Extract all text content from this document and format it as clean markdown. Preserve headings, lists, tables, and formatting structure. Do not add any commentary - just return the document content as markdown."
      }
    ]

    image_paths.each do |path|
      base64_image = Base64.strict_encode64(File.read(path))
      content << {
        type: "image_url",
        image_url: { url: "data:image/png;base64,#{base64_image}" }
      }
    end

    response = client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [{ role: "user", content: content }],
        max_tokens: 16000
      }
    )

    content = response.dig("choices", 0, "message", "content")
    strip_markdown_fence(content)
  rescue => e
    Rails.logger.error "OpenAI extraction failed: #{e.message}"
    nil
  end

  def strip_markdown_fence(content)
    return nil if content.blank?

    # Remove ```markdown wrapper if present
    content.gsub(/\A```markdown\s*\n?/, "").gsub(/\n?```\s*\z/, "").strip
  end

  def sanitize_and_extract(content)
    client = OpenAI::Client.new

    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: <<~PROMPT
              You are a document processor. Process this markdown document and return JSON with two fields:

              1. "published_at": Extract the publication/effective date from the document header (YYYY-MM-DD format, or null if not found)

              2. "content": The cleaned markdown with:
                 - Publication date removed from header
                 - Company name removed from header (e.g., 'Homecare D & D Ltd')
                 - Any Pandoc-specific markup cleaned up (like {.mark}, {.underline}, [text]{.attribute})
                 - All actual content and standard markdown formatting preserved (headings, lists, bold, italic, tables)

              Return ONLY valid JSON, no markdown code fences.
            PROMPT
          },
          { role: "user", content: content }
        ],
        max_tokens: 16000
      }
    )

    result = response.dig("choices", 0, "message", "content")
    result = strip_markdown_fence(result)
    parsed = JSON.parse(result)

    published_at = parsed["published_at"].present? ? Date.parse(parsed["published_at"]) : nil
    cleaned_content = parsed["content"]

    Result.new(content: cleaned_content, published_at: published_at)
  rescue => e
    Rails.logger.error "Sanitize and extract failed: #{e.message}"
    Result.new(content: content, published_at: nil)
  end
end
