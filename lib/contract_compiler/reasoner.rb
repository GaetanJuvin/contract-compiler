# lib/contract_compiler/reasoner.rb
require "set"

module ContractCompiler
  class Reasoner
    def self.analyze(graph)
      anomalies = []
      anomalies.concat(check_circular_dependencies(graph))
      anomalies.concat(check_contradictory_obligations(graph))
      anomalies.concat(check_orphaned_obligations(graph))
      anomalies.concat(check_dangling_conditions(graph))
      anomalies.concat(check_missing_reciprocity(graph))
      anomalies.concat(check_unmatched_references(graph))
      anomalies
    end

    def self.node_lines(graph, node_ids)
      node_ids.filter_map { |id| graph.find_node(id)&.line }.compact.uniq.sort
    end

    def self.check_circular_dependencies(graph)
      cycles = graph.cycle_detect
      cycles.map do |cycle|
        lines = node_lines(graph, cycle)
        {
          type: :circular_dependency,
          severity: :critical,
          description: "Circular dependency detected: #{cycle.join(" -> ")}",
          involved_nodes: cycle,
          lines: lines
        }
      end
    end

    def self.check_contradictory_obligations(graph)
      anomalies = []
      obligations = graph.nodes.select { |n| n.type == :obligation }

      obligations.combination(2).each do |o1, o2|
        next unless o1.party.downcase == o2.party.downcase

        a1 = o1.action.downcase.gsub(/\bnot\s+/, "")
        a2 = o2.action.downcase.gsub(/\bnot\s+/, "")
        negated1 = o1.action.downcase.include?("not ")
        negated2 = o2.action.downcase.include?("not ")

        if similar_actions?(a1, a2) && negated1 != negated2
          lines = [o1.line, o2.line].compact.sort
          anomalies << {
            type: :contradictory_obligations,
            severity: :critical,
            description: "#{o1.party} has contradictory obligations: '#{o1.action}' vs '#{o2.action}'",
            involved_nodes: [o1.id, o2.id],
            lines: lines
          }
        end
      end

      anomalies
    end

    def self.check_orphaned_obligations(graph)
      graph.nodes
        .select { |n| n.type == :obligation && (n.party.nil? || n.party.strip.empty?) }
        .map do |node|
          {
            type: :orphaned_obligation,
            severity: :high,
            description: "Obligation '#{node.action}' has no associated party",
            involved_nodes: [node.id],
            lines: [node.line].compact
          }
        end
    end

    def self.check_dangling_conditions(graph)
      graph.nodes
        .select { |n| n.type == :condition }
        .select { |n| graph.edges.none? { |e| e.from == n.id && e.type != :derived_from } && graph.edges.none? { |e| e.to == n.id && e.type == :depends_on } }
        .map do |node|
          {
            type: :dangling_condition,
            severity: :medium,
            description: "Condition '#{node.trigger}' is defined but never referenced by any obligation or right",
            involved_nodes: [node.id],
            lines: [node.line].compact
          }
        end
    end

    def self.check_missing_reciprocity(graph)
      anomalies = []
      obligations = graph.nodes.select { |n| n.type == :obligation }
      rights = graph.nodes.select { |n| n.type == :right }

      parties_with_obligations = obligations.map { |o| o.party.downcase }.uniq
      parties_with_rights = rights.map { |r| r.party.downcase }.uniq

      parties_with_obligations.each do |party|
        unless parties_with_rights.include?(party)
          party_obls = obligations.select { |o| o.party.downcase == party }
          lines = party_obls.filter_map(&:line).compact.uniq.sort
          anomalies << {
            type: :missing_reciprocity,
            severity: :medium,
            description: "Party '#{party}' has obligations but no corresponding rights",
            involved_nodes: party_obls.map(&:id),
            lines: lines
          }
        end
      end

      anomalies
    end

    def self.check_unmatched_references(graph)
      anomalies = []
      clause_ids = graph.nodes.select { |n| n.type == :clause }.map(&:id)

      graph.nodes.select { |n| n.type == :condition }.each do |cond|
        cond.referenced_clauses.each do |ref|
          matching = clause_ids.any? { |cid| cid.include?(ref) }
          unless matching
            anomalies << {
              type: :unmatched_reference,
              severity: :high,
              description: "Condition '#{cond.trigger}' references clause '#{ref}' which does not exist",
              involved_nodes: [cond.id],
              lines: [cond.line].compact
            }
          end
        end
      end

      anomalies
    end

    def self.similar_actions?(a1, a2)
      words1 = a1.split(/\s+/).to_set
      words2 = a2.split(/\s+/).to_set
      intersection = words1 & words2
      union = words1 | words2
      return false if union.empty?

      (intersection.size.to_f / union.size) > 0.5
    end

    private_class_method :check_circular_dependencies, :check_contradictory_obligations,
                         :check_orphaned_obligations, :check_dangling_conditions,
                         :check_missing_reciprocity, :check_unmatched_references,
                         :similar_actions?, :node_lines
  end
end
