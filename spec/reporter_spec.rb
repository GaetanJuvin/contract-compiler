# spec/reporter_spec.rb
require "spec_helper"
require "json"

RSpec.describe ContractCompiler::Reporter do
  let(:anomalies) do
    [
      { type: :contradictory_obligations, severity: :critical, description: "Conflict in clauses 4 and 7", involved_nodes: ["obl1", "obl2"], source: :symbolic },
      { type: :ambiguous_language, severity: :high, description: "Term 'reasonable' undefined", involved_nodes: ["clause_1"], source: :ai, recommendation: "Define the term" },
      { type: :dangling_condition, severity: :medium, description: "Unused condition", involved_nodes: ["cond1"], source: :symbolic },
      { type: :inconsistent_definitions, severity: :low, description: "Minor wording difference", involved_nodes: ["clause_2"], source: :ai, recommendation: "Align wording" },
    ]
  end

  let(:metadata) do
    { source_file: "contract.pdf", clause_count: 24, party_count: 3 }
  end

  describe ".format_text" do
    it "produces a formatted report" do
      output = described_class.format_text(anomalies: anomalies, metadata: metadata)
      expect(output).to include("Contract Analysis Report")
      expect(output).to include("contract.pdf")
      expect(output).to include("CRITICAL (1)")
      expect(output).to include("HIGH (1)")
      expect(output).to include("MEDIUM (1)")
      expect(output).to include("LOW (1)")
      expect(output).to include("Conflict in clauses 4 and 7")
    end

    it "shows summary line" do
      output = described_class.format_text(anomalies: anomalies, metadata: metadata)
      expect(output).to include("Summary:")
    end
  end

  describe ".format_json" do
    it "produces valid JSON with all data" do
      output = described_class.format_json(anomalies: anomalies, metadata: metadata, graph_hash: { nodes: [], edges: [] })
      parsed = JSON.parse(output)
      expect(parsed["anomalies"].length).to eq(4)
      expect(parsed["metadata"]["source_file"]).to eq("contract.pdf")
      expect(parsed["graph"]).to have_key("nodes")
    end
  end
end
