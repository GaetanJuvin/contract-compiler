# lib/contract_compiler/semantic_extractor.rb
module ContractCompiler
  class SemanticExtractor
    OBLIGATION_PATTERNS = [
      /(?:the\s+)?(\w+)\s+(?:shall|must|agrees?\s+to|is\s+required\s+to)\s+(.+?)(?:\.\s|$)/i,
    ].freeze

    RIGHT_PATTERNS = [
      /(?:the\s+)?(\w+)\s+(?:may|is\s+entitled\s+to|has\s+the\s+right\s+to)\s+(.+?)(?:\.\s|$)/i,
    ].freeze

    CONDITION_PATTERNS = [
      /(?:if|provided\s+that|subject\s+to|upon)\s+(.+?),\s*(.+?)(?:\.\s|$)/i,
    ].freeze

    TEMPORAL_PATTERN = /(?:within|before|after|no\s+later\s+than)\s+(\d+\s+\w+)/i

    COMMON_PARTY_WORDS = %w[Seller Buyer Company Employee Contractor Client Landlord Tenant Licensor Licensee Provider Customer Vendor Supplier Lessee Lessor Borrower Lender].freeze

    def self.extract_parties(text)
      parties = []
      COMMON_PARTY_WORDS.each do |word|
        parties << word if text.match?(/\b#{word}\b/i)
      end
      parties.uniq
    end

    def self.extract(clauses)
      nodes = []
      edges = []
      counters = { obligation: 0, right: 0, condition: 0 }

      clauses.each do |clause|
        extract_obligations(clause, nodes, edges, counters)
        extract_rights(clause, nodes, edges, counters)
        extract_conditions(clause, nodes, edges, counters)
      end

      { nodes: nodes, edges: edges }
    end

    def self.clause_text(clause)
      text = clause.body.to_s.strip
      text = clause.title.to_s.strip if text.empty?
      text
    end

    def self.find_match_line(clause, match_text)
      return clause.line unless clause.line && match_text

      # Search within the clause body for the matching text line offset
      body = clause.body.to_s
      body = clause.title.to_s if body.strip.empty?
      body.lines.each_with_index do |line, idx|
        if line.downcase.include?(match_text[0..30].downcase)
          return clause.line + idx
        end
      end
      clause.line
    end

    def self.extract_obligations(clause, nodes, edges, counters)
      text = clause_text(clause)
      OBLIGATION_PATTERNS.each do |pattern|
        text.scan(pattern) do |party, action|
          counters[:obligation] += 1
          id = "obl_#{counters[:obligation]}"
          temporal = action.match(TEMPORAL_PATTERN)&.send(:[], 0)
          target = detect_target_party(action)
          match_line = find_match_line(clause, action)

          nodes << DAG::ObligationNode.new(
            id: id,
            party: party.strip,
            action: action.strip,
            target_party: target,
            temporal: temporal,
            line: match_line
          )
          edges << { from: clause.id, to: id, type: :derived_from }
        end
      end
    end

    def self.extract_rights(clause, nodes, edges, counters)
      text = clause_text(clause)
      RIGHT_PATTERNS.each do |pattern|
        text.scan(pattern) do |party, entitlement|
          counters[:right] += 1
          id = "right_#{counters[:right]}"
          match_line = find_match_line(clause, entitlement)

          nodes << DAG::RightNode.new(
            id: id,
            party: party.strip,
            entitlement: entitlement.strip,
            line: match_line
          )
          edges << { from: clause.id, to: id, type: :derived_from }
        end
      end
    end

    def self.extract_conditions(clause, nodes, edges, counters)
      text = clause_text(clause)
      CONDITION_PATTERNS.each do |pattern|
        text.scan(pattern) do |trigger, consequence|
          counters[:condition] += 1
          id = "cond_#{counters[:condition]}"
          refs = extract_clause_references(trigger + " " + consequence)
          match_line = find_match_line(clause, trigger)

          nodes << DAG::ConditionNode.new(
            id: id,
            trigger: trigger.strip,
            consequence: consequence.strip,
            referenced_clauses: refs,
            line: match_line
          )
          edges << { from: clause.id, to: id, type: :derived_from }
        end
      end
    end

    def self.detect_target_party(text)
      COMMON_PARTY_WORDS.each do |word|
        return word if text.match?(/\b#{word}\b/i)
      end
      nil
    end

    def self.extract_clause_references(text)
      refs = []
      text.scan(/(?:clause|section|article)\s+(\d+(?:\.\d+)*)/i) do |num|
        refs << num[0]
      end
      refs
    end

    private_class_method :extract_obligations, :extract_rights, :extract_conditions,
                         :detect_target_party, :extract_clause_references, :clause_text,
                         :find_match_line
  end
end
