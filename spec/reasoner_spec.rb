# spec/reasoner_spec.rb
require "spec_helper"

RSpec.describe ContractCompiler::Reasoner do
  let(:graph) { ContractCompiler::DAG::Graph.new }

  describe ".analyze" do
    it "returns an array of Anomaly hashes" do
      anomalies = described_class.analyze(graph)
      expect(anomalies).to be_an(Array)
    end

    it "detects circular dependencies" do
      n1 = ContractCompiler::DAG::ConditionNode.new(id: "cond1", trigger: "if A", consequence: "then B")
      n2 = ContractCompiler::DAG::ConditionNode.new(id: "cond2", trigger: "if B", consequence: "then A")
      graph.add_node(n1)
      graph.add_node(n2)
      graph.add_edge(from: "cond1", to: "cond2", type: :depends_on)
      graph.add_edge(from: "cond2", to: "cond1", type: :depends_on)

      anomalies = described_class.analyze(graph)
      types = anomalies.map { |a| a[:type] }
      expect(types).to include(:circular_dependency)
    end

    it "detects contradictory obligations" do
      c1 = ContractCompiler::DAG::ClauseNode.new(id: "c1", title: "A", body: "A", level: 1, parent_id: nil)
      c2 = ContractCompiler::DAG::ClauseNode.new(id: "c2", title: "B", body: "B", level: 1, parent_id: nil)
      o1 = ContractCompiler::DAG::ObligationNode.new(id: "obl1", party: "Seller", action: "deliver goods", target_party: "Buyer")
      o2 = ContractCompiler::DAG::ObligationNode.new(id: "obl2", party: "Seller", action: "not deliver goods", target_party: "Buyer")
      graph.add_node(c1)
      graph.add_node(c2)
      graph.add_node(o1)
      graph.add_node(o2)
      graph.add_edge(from: "c1", to: "obl1", type: :derived_from)
      graph.add_edge(from: "c2", to: "obl2", type: :derived_from)

      anomalies = described_class.analyze(graph)
      types = anomalies.map { |a| a[:type] }
      expect(types).to include(:contradictory_obligations)
    end

    it "detects orphaned obligations (no party)" do
      o = ContractCompiler::DAG::ObligationNode.new(id: "obl1", party: "", action: "do something", target_party: "Buyer")
      graph.add_node(o)

      anomalies = described_class.analyze(graph)
      types = anomalies.map { |a| a[:type] }
      expect(types).to include(:orphaned_obligation)
    end

    it "detects dangling conditions" do
      c = ContractCompiler::DAG::ConditionNode.new(id: "cond1", trigger: "if X", consequence: "then Y")
      graph.add_node(c)

      anomalies = described_class.analyze(graph)
      types = anomalies.map { |a| a[:type] }
      expect(types).to include(:dangling_condition)
    end

    it "detects missing reciprocity" do
      c1 = ContractCompiler::DAG::ClauseNode.new(id: "c1", title: "A", body: "A", level: 1, parent_id: nil)
      o1 = ContractCompiler::DAG::ObligationNode.new(id: "obl1", party: "Seller", action: "deliver", target_party: "Buyer")
      o2 = ContractCompiler::DAG::ObligationNode.new(id: "obl2", party: "Seller", action: "warrant", target_party: "Buyer")
      graph.add_node(c1)
      graph.add_node(o1)
      graph.add_node(o2)
      graph.add_edge(from: "c1", to: "obl1", type: :derived_from)
      graph.add_edge(from: "c1", to: "obl2", type: :derived_from)

      anomalies = described_class.analyze(graph)
      types = anomalies.map { |a| a[:type] }
      expect(types).to include(:missing_reciprocity)
    end
  end
end
