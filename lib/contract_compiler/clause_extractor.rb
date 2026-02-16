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

      lines.each do |line|
        if (match = line.match(NUMBERED_SECTION))
          if current_number
            sections << { number: current_number, title: current_title, body: current_body_lines.join.strip, level: current_level }
          end
          current_number = match[1]
          current_title = match[2].strip
          current_body_lines = []
          current_level = current_number.count(".") + 1
        elsif (match = line.match(SUBSECTION))
          if current_number
            sections << { number: current_number, title: current_title, body: current_body_lines.join.strip, level: current_level }
          end
          current_number = match[1]
          current_title = match[2].strip
          current_body_lines = []
          current_level = current_number.count(".") + 1
        elsif (match = line.match(ARTICLE_SECTION))
          if current_number
            sections << { number: current_number, title: current_title, body: current_body_lines.join.strip, level: current_level }
          end
          current_number = match[1]
          current_title = match[2].strip
          current_body_lines = []
          current_level = 1
        else
          current_body_lines << line if current_number
        end
      end

      if current_number
        sections << { number: current_number, title: current_title, body: current_body_lines.join.strip, level: current_level }
      end

      build_clause_nodes(sections)
    end

    def self.try_paragraph_fallback(text)
      paragraphs = text.split(/\n\s*\n/).map(&:strip).reject(&:empty?)
      paragraphs.each_with_index.map do |para, i|
        DAG::ClauseNode.new(
          id: "clause_#{i + 1}",
          title: "Section #{i + 1}",
          body: para,
          level: 1,
          parent_id: nil
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
          parent_id: parent_id
        )
      end
    end

    private_class_method :try_numbered_extraction, :try_paragraph_fallback, :build_clause_nodes
  end
end
