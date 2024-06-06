class Resume < ApplicationRecord
  has_one_attached :file

  def extract_text
    if file.content_type == 'application/pdf'
      extract_text_from_pdf
    elsif file.content_type == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      extract_text_from_docx
    else
      "Unsupported file type"
    end
  end

  private

  def extract_text_from_pdf
    reader = PDF::Reader.new(file.download)
    text = reader.pages.map(&:text).join(" ")
    text
  end

  def extract_text_from_docx
    doc = Docx::Document.open(file.download)
    text = doc.paragraphs.map(&:to_s).join(" ")
    text
  end
end
