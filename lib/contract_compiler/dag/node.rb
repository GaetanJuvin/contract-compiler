# lib/contract_compiler/dag/node.rb
module ContractCompiler
  module DAG
    class ClauseNode
      attr_reader :id, :title, :body, :level, :parent_id

      def initialize(id:, title:, body:, level:, parent_id:)
        @id = id
        @title = title
        @body = body
        @level = level
        @parent_id = parent_id
      end

      def type
        :clause
      end

      def to_hash
        { id: @id, type: type, title: @title, body: @body, level: @level, parent_id: @parent_id }
      end
    end

    class ObligationNode
      attr_reader :id, :party, :action, :target_party, :temporal

      def initialize(id:, party:, action:, target_party:, temporal: nil)
        @id = id
        @party = party
        @action = action
        @target_party = target_party
        @temporal = temporal
      end

      def type
        :obligation
      end

      def to_hash
        { id: @id, type: type, party: @party, action: @action, target_party: @target_party, temporal: @temporal }
      end
    end

    class RightNode
      attr_reader :id, :party, :entitlement, :scope

      def initialize(id:, party:, entitlement:, scope: nil)
        @id = id
        @party = party
        @entitlement = entitlement
        @scope = scope
      end

      def type
        :right
      end

      def to_hash
        { id: @id, type: type, party: @party, entitlement: @entitlement, scope: @scope }
      end
    end

    class ConditionNode
      attr_reader :id, :trigger, :consequence, :referenced_clauses

      def initialize(id:, trigger:, consequence:, referenced_clauses: [])
        @id = id
        @trigger = trigger
        @consequence = consequence
        @referenced_clauses = referenced_clauses
      end

      def type
        :condition
      end

      def to_hash
        { id: @id, type: type, trigger: @trigger, consequence: @consequence, referenced_clauses: @referenced_clauses }
      end
    end
  end
end
