# lib/contract_compiler/dag/node.rb
module ContractCompiler
  module DAG
    class ClauseNode
      attr_reader :id, :title, :body, :level, :parent_id, :line

      def initialize(id:, title:, body:, level:, parent_id:, line: nil)
        @id = id
        @title = title
        @body = body
        @level = level
        @parent_id = parent_id
        @line = line
      end

      def type
        :clause
      end

      def to_hash
        { id: @id, type: type, title: @title, body: @body, level: @level, parent_id: @parent_id, line: @line }
      end
    end

    class ObligationNode
      attr_reader :id, :party, :action, :target_party, :temporal, :line

      def initialize(id:, party:, action:, target_party:, temporal: nil, line: nil)
        @id = id
        @party = party
        @action = action
        @target_party = target_party
        @temporal = temporal
        @line = line
      end

      def type
        :obligation
      end

      def to_hash
        { id: @id, type: type, party: @party, action: @action, target_party: @target_party, temporal: @temporal, line: @line }
      end
    end

    class RightNode
      attr_reader :id, :party, :entitlement, :scope, :line

      def initialize(id:, party:, entitlement:, scope: nil, line: nil)
        @id = id
        @party = party
        @entitlement = entitlement
        @scope = scope
        @line = line
      end

      def type
        :right
      end

      def to_hash
        { id: @id, type: type, party: @party, entitlement: @entitlement, scope: @scope, line: @line }
      end
    end

    class ConditionNode
      attr_reader :id, :trigger, :consequence, :referenced_clauses, :line

      def initialize(id:, trigger:, consequence:, referenced_clauses: [], line: nil)
        @id = id
        @trigger = trigger
        @consequence = consequence
        @referenced_clauses = referenced_clauses
        @line = line
      end

      def type
        :condition
      end

      def to_hash
        { id: @id, type: type, trigger: @trigger, consequence: @consequence, referenced_clauses: @referenced_clauses, line: @line }
      end
    end
  end
end
