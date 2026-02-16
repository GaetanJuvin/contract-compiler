# lib/contract_compiler/clause_extractor.rb
module ContractCompiler
  class ClauseExtractor
    NUMBERED_SECTION = /^(\d+(?:\.\d+)*)\.\s+(.+)$/
    SUBSECTION = /^(\d+\.\d+(?:\.\d+)*)\s+(.+)$/
    ARTICLE_SECTION = /^(Article\s+[IVXLCDM\d]+)[:\.\s]*(.*)$/i

    def self.extract(text)
      clauses = try_numbered_extraction(text)
      clauses = try_paragraph_fallback(text) if clauses.empty?
      clauses
    end

    def self.try_numbered_extraction(text)
      lines = text.lines
      sections = []
      current_number = nil
      current_title = nil
      current_body_lines = []
      current_level = nil
      current_line = nil

      lines.each_with_index do |line, idx|
        line_num = idx + 1

        if (match = line.match(NUMBERED_SECTION))
          if current_number
            sections << { number: current_number, title: current_title, body: current_body_lines.join.strip, level: current_level, line: current_line }
          end
          current_number = match[1]
          current_title = match[2].strip
          current_body_lines = []
          current_level = current_number.count(".") + 1
          current_line = line_num
        elsif (match = line.match(SUBSECTION))
          if current_number
            sections << { number: current_number, title: current_title, body: current_body_lines.join.strip, level: current_level, line: current_line }
          end
          current_number = match[1]
          current_title = match[2].strip
          current_body_lines = []
          current_level = current_number.count(".") + 1
          current_line = line_num
        elsif (match = line.match(ARTICLE_SECTION))
          if current_number
            sections << { number: current_number, title: current_title, body: current_body_lines.join.strip, level: current_level, line: current_line }
          end
          current_number = match[1]
          current_title = match[2].strip
          current_body_lines = []
          current_level = 1
          current_line = line_num
        else
          current_body_lines << line if current_number
        end
      end

      if current_number
        sections << { number: current_number, title: current_title, body: current_body_lines.join.strip, level: current_level, line: current_line }
      end

      build_clause_nodes(sections)
    end

    def self.try_paragraph_fallback(text)
      # Track line numbers for paragraph splits
      paragraphs = []
      current_lines = []
      current_start_line = nil

      text.lines.each_with_index do |line, idx|
        line_num = idx + 1
        if line.strip.empty?
          if current_lines.any?
            paragraphs << { text: current_lines.join.strip, line: current_start_line }
            current_lines = []
            current_start_line = nil
          end
        else
          current_start_line ||= line_num
          current_lines << line
        end
      end
      paragraphs << { text: current_lines.join.strip, line: current_start_line } if current_lines.any?

      paragraphs.reject { |p| p[:text].empty? }.each_with_index.map do |para, i|
        DAG::ClauseNode.new(
          id: "clause_#{i + 1}",
          title: "Section #{i + 1}",
          body: para[:text],
          level: 1,
          parent_id: nil,
          line: para[:line]
        )
      end
    end

    def self.build_clause_nodes(sections)
      parent_stack = []

      sections.map.with_index do |sec, i|
        while parent_stack.any? && parent_stack.last[:level] >= sec[:level]
          parent_stack.pop
        end
        parent_id = parent_stack.last&.dig(:id)
        id = "clause_#{i + 1}"

        parent_stack.push({ id: id, level: sec[:level] })

        DAG::ClauseNode.new(
          id: id,
          title: sec[:title],
          body: sec[:body],
          level: sec[:level],
          parent_id: parent_id,
          line: sec[:line]
        )
      end
    end

    private_class_method :try_numbered_extraction, :try_paragraph_fallback, :build_clause_nodes
  end
end
