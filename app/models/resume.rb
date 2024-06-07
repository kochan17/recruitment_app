# app/models/resume.rb
class Resume < ApplicationRecord
  has_one_attached :file
  has_many_attached :photos

  after_save :extract_faces

  def extract_text
    if file.content_type == 'application/pdf'
      extract_text_from_pdf
    elsif file.content_type == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      extract_text_from_docx
    else
      "Unsupported file type"
    end
  end

  def analyze_text
    text = extract_text
    client = OpenAI::Client.new
    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [{ role: "user", content: analyze_prompt(text) }],
        max_tokens: 500
      }
    )
    parsed_response = parse_analysis_response(response['choices'][0]['message']['content'].strip)
    parsed_response.merge({ verdict: make_verdict(parsed_response) })
  end

  private

  def analyze_prompt(text)
    <<-PROMPT
    あなたは大手企業で採用担当の経験がある、プロの人事マンです。現在は以下の課題を抱えています。
    # 課題
    自分が働く企業の応募人数が多すぎて書類選考を捌けていない
    
    ソリューションは以下のとおりです。

    # ソリューション
    ファイルをアップロードし、自社の採用基準に合致する人か判断するアプリを使用する

    上記のアプリは、このアプリのことです。

    # 依頼
    アップロードされたファイルから以下の情報を分析し、各項目を10段階で評価してください。また、総合評価も行ってください。

    # 情報
    1. 名前
    2. 経歴
    3. 強み
    4. 実績
    5. 弱み
    6. 性格
    7. 各項目の10段階評価
    8. 総合評価

    テキスト:
    #{text}
    PROMPT
  end

  def parse_analysis_response(response)
    result = {
      name: extract_section(response, "名前"),
      background: extract_section(response, "経歴"),
      strengths: extract_section(response, "強み"),
      achievements: extract_section(response, "実績"),
      weaknesses: extract_section(response, "弱み"),
      personality: extract_section(response, "性格"),
      strengths_score: extract_score(response, "強み"),
      achievements_score: extract_score(response, "実績"),
      personality_score: extract_score(response, "性格")
    }
    result.merge({ overall_rating: make_overall_rating(result) })
  end

  def extract_section(response, section_name)
    match = response.match(/#{section_name}:?\s*(.*?)(?:\n(?:\d+\.|$)|$)/m)
    match ? match[1].strip : ""
  end

  def extract_score(response, section_name)
    match = response.match(/#{section_name}評価:\s*(\d+)/)
    match ? match[1].to_i : 0
  end

  def make_verdict(parsed_response)
    # 簡単な判定ロジック
    if parsed_response[:strengths].present? && parsed_response[:achievements].present?
      "一次面接に通過"
    else
      "一次面接に不合格"
    end
  end

  def make_overall_rating(parsed_response)
    average_score = (parsed_response[:strengths_score] + parsed_response[:achievements_score] + parsed_response[:personality_score]) / 3.0
    if average_score >= 7
      "A"
    elsif average_score >= 5
      "B"
    else
      "C"
    end
  end

  def extract_faces
    file_path = ActiveStorage::Blob.service.send(:path_for, file.key)
    extract_images_from_file(file_path).each do |image_path|
      detect_faces(image_path).each do |face_image_path|
        photos.attach(io: File.open(face_image_path), filename: File.basename(face_image_path))
        File.delete(face_image_path)  # Clean up face images after attaching
      end
      File.delete(image_path)  # Clean up extracted images
    end
  end

  def extract_images_from_file(file_path)
    images = []
    if file.content_type == 'application/pdf'
      images = extract_images_from_pdf(file_path)
    elsif file.content_type == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      images = extract_images_from_docx(file_path)
    else
      raise "Unsupported file type"
    end
    images
  end

  def extract_images_from_pdf(pdf_path)
    images = []
    MiniMagick::Tool::Magick.new do |magick|
      magick << pdf_path
      magick << "output.png"
    end
    Dir.glob("output-*.png") { |image| images << image }
    images
  end

  def extract_images_from_docx(docx_path)
    images = []
    doc = Docx::Document.open(docx_path)
    doc.images.each_with_index do |image, index|
      image_path = "image-#{index}.png"
      File.open(image_path, "wb") { |file| file.write(image.data) }
      images << image_path
    end
    images
  end

  def detect_faces(image_path)
    face_images = []
    image = MiniMagick::Image.open(image_path)
    image.combine_options do |c|
      c.gravity 'center'
      c.crop '256x256+0+0'
    end
    face_image_path = "face_#{File.basename(image_path)}"
    image.write(face_image_path)
    face_images << face_image_path
    face_images
  end
end
