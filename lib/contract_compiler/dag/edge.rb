# lib/contract_compiler/dag/edge.rb
module ContractCompiler
  module DAG
    class Edge
      VALID_TYPES = %i[references derived_from depends_on conflicts_with].freeze

      attr_reader :from, :to, :type

      def initialize(from:, to:, type:)
        raise ArgumentError, "Invalid edge type: #{type}" unless VALID_TYPES.include?(type)

        @from = from
        @to = to
        @type = type
      end

      def to_hash
        { from: @from, to: @to, type: @type }
      end
    end
  end
end
