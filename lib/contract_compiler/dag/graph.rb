# lib/contract_compiler/dag/graph.rb
module ContractCompiler
  module DAG
    class Graph
      attr_reader :nodes, :edges

      def initialize
        @nodes = []
        @edges = []
        @node_index = {}
      end

      def add_node(node)
        raise ArgumentError, "Duplicate node id: #{node.id}" if @node_index.key?(node.id)

        @nodes << node
        @node_index[node.id] = node
        node
      end

      def find_node(id)
        @node_index[id]
      end

      def add_edge(from:, to:, type:)
        raise ArgumentError, "Unknown node: #{from}" unless @node_index.key?(from)
        raise ArgumentError, "Unknown node: #{to}" unless @node_index.key?(to)

        edge = Edge.new(from: from, to: to, type: type)
        @edges << edge
        edge
      end

      def neighbors(node_id)
        @edges.select { |e| e.from == node_id }.map { |e| @node_index[e.to] }
      end

      def cycle_detect
        visited = {}
        rec_stack = {}
        cycles = []

        @node_index.each_key do |node_id|
          next if visited[node_id]

          cycle_dfs(node_id, visited, rec_stack, [], cycles)
        end

        cycles
      end

      def topological_sort
        visited = {}
        stack = []

        @node_index.each_key do |node_id|
          topo_dfs(node_id, visited, stack) unless visited[node_id]
        end

        stack.reverse
      end

      def find_paths(from, to, path = [], all_paths = [])
        path = path + [from]

        if from == to
          all_paths << path.dup
          return all_paths
        end

        @edges.select { |e| e.from == from }.each do |edge|
          next if path.include?(edge.to)

          find_paths(edge.to, to, path, all_paths)
        end

        all_paths
      end

      def to_hash
        {
          nodes: @nodes.map(&:to_hash),
          edges: @edges.map(&:to_hash)
        }
      end

      private

      def cycle_dfs(node_id, visited, rec_stack, path, cycles)
        visited[node_id] = true
        rec_stack[node_id] = true
        path.push(node_id)

        @edges.select { |e| e.from == node_id }.each do |edge|
          if !visited[edge.to]
            cycle_dfs(edge.to, visited, rec_stack, path, cycles)
          elsif rec_stack[edge.to]
            cycle_start = path.index(edge.to)
            cycles << path[cycle_start..] + [edge.to]
          end
        end

        path.pop
        rec_stack[node_id] = false
      end

      def topo_dfs(node_id, visited, stack)
        visited[node_id] = true

        @edges.select { |e| e.from == node_id }.each do |edge|
          topo_dfs(edge.to, visited, stack) unless visited[edge.to]
        end

        stack.push(@node_index[node_id])
      end
    end
  end
end
