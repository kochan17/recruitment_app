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
    - アップロードされたファイルから以下の{# 情報}を分析して出力してください。
    - 口調は「である調」にしてください。

    # 情報
    1. 名前
    2. 経歴
    3. 強み
    4. 実績
    5. 弱み
    6. 性格

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
      personality: extract_section(response, "性格")
    }
    result
  end

  def extract_section(response, section_name)
    match = response.match(/#{section_name}:?\s*(.*?)(?:\n(?:\d+\.|$)|$)/m)
    match ? match[1].strip : ""
  end

  def make_verdict(parsed_response)
    # 簡単な判定ロジック
    if parsed_response[:strengths].present? && parsed_response[:achievements].present?
      "一次面接に通過"
    else
      "一次面接に不合格"
    end
  end

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
