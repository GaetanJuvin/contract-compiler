require "spec_helper"

RSpec.describe ContractCompiler::DAG::Graph do
  let(:graph) { described_class.new }

  let(:clause1) { ContractCompiler::DAG::ClauseNode.new(id: "c1", title: "Definitions", body: "Terms defined here.", level: 1, parent_id: nil) }
  let(:clause2) { ContractCompiler::DAG::ClauseNode.new(id: "c2", title: "Obligations", body: "Seller shall deliver.", level: 1, parent_id: nil) }
  let(:obl1) { ContractCompiler::DAG::ObligationNode.new(id: "obl1", party: "Seller", action: "deliver goods", target_party: "Buyer") }

  describe "#add_node" do
    it "adds a node" do
      graph.add_node(clause1)
      expect(graph.nodes).to include(clause1)
    end

    it "rejects duplicate node ids" do
      graph.add_node(clause1)
      dupe = ContractCompiler::DAG::ClauseNode.new(id: "c1", title: "Dupe", body: "Dupe", level: 1, parent_id: nil)
      expect { graph.add_node(dupe) }.to raise_error(ArgumentError, /duplicate node/i)
    end
  end

  describe "#add_edge" do
    it "adds an edge between existing nodes" do
      graph.add_node(clause1)
      graph.add_node(obl1)
      edge = graph.add_edge(from: "c1", to: "obl1", type: :derived_from)
      expect(graph.edges).to include(edge)
    end

    it "rejects edges with unknown node ids" do
      graph.add_node(clause1)
      expect { graph.add_edge(from: "c1", to: "unknown", type: :references) }.to raise_error(ArgumentError, /unknown node/i)
    end
  end

  describe "#cycle_detect" do
    it "returns empty for acyclic graph" do
      graph.add_node(clause1)
      graph.add_node(clause2)
      graph.add_node(obl1)
      graph.add_edge(from: "c1", to: "c2", type: :references)
      graph.add_edge(from: "c2", to: "obl1", type: :derived_from)

      expect(graph.cycle_detect).to eq([])
    end

    it "detects cycles" do
      n1 = ContractCompiler::DAG::ConditionNode.new(id: "cond1", trigger: "if A", consequence: "then B")
      n2 = ContractCompiler::DAG::ConditionNode.new(id: "cond2", trigger: "if B", consequence: "then A")
      graph.add_node(n1)
      graph.add_node(n2)
      graph.add_edge(from: "cond1", to: "cond2", type: :depends_on)
      graph.add_edge(from: "cond2", to: "cond1", type: :depends_on)

      cycles = graph.cycle_detect
      expect(cycles).not_to be_empty
    end
  end

  describe "#topological_sort" do
    it "returns nodes in dependency order" do
      graph.add_node(clause1)
      graph.add_node(clause2)
      graph.add_node(obl1)
      graph.add_edge(from: "c1", to: "c2", type: :references)
      graph.add_edge(from: "c2", to: "obl1", type: :derived_from)

      sorted_ids = graph.topological_sort.map(&:id)
      expect(sorted_ids.index("c1")).to be < sorted_ids.index("c2")
      expect(sorted_ids.index("c2")).to be < sorted_ids.index("obl1")
    end
  end

  describe "#find_paths" do
    it "finds all paths between two nodes" do
      graph.add_node(clause1)
      graph.add_node(clause2)
      graph.add_node(obl1)
      graph.add_edge(from: "c1", to: "c2", type: :references)
      graph.add_edge(from: "c2", to: "obl1", type: :derived_from)
      graph.add_edge(from: "c1", to: "obl1", type: :derived_from)

      paths = graph.find_paths("c1", "obl1")
      expect(paths.length).to eq(2)
    end
  end

  describe "#to_hash" do
    it "serializes the full graph" do
      graph.add_node(clause1)
      graph.add_node(obl1)
      graph.add_edge(from: "c1", to: "obl1", type: :derived_from)

      hash = graph.to_hash
      expect(hash[:nodes].length).to eq(2)
      expect(hash[:edges].length).to eq(1)
    end
  end
end
