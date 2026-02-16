# spec/analyzer_spec.rb
require "spec_helper"

RSpec.describe ContractCompiler::Analyzer do
  describe ".build_prompt" do
    it "builds a proper prompt with graph, text, and existing anomalies" do
      prompt = described_class.build_prompt(
        graph_hash: { nodes: [], edges: [] },
        original_text: "Sample contract text.",
        symbolic_anomalies: []
      )

      expect(prompt).to include("Sample contract text.")
      expect(prompt).to include("nodes")
      expect(prompt).to include("anomalies")
    end
  end

  describe ".parse_response" do
    it "parses a valid JSON response into anomaly hashes" do
      json_response = {
        "anomalies" => [
          {
            "type" => "ambiguous_language",
            "severity" => "medium",
            "description" => "Term 'reasonable' is not defined",
            "involved_clauses" => ["clause_1"],
            "recommendation" => "Define 'reasonable' in the Definitions section"
          }
        ]
      }.to_json

      anomalies = described_class.parse_response(json_response)
      expect(anomalies.length).to eq(1)
      expect(anomalies.first[:type]).to eq(:ambiguous_language)
      expect(anomalies.first[:severity]).to eq(:medium)
    end

    it "returns empty array for malformed response" do
      anomalies = described_class.parse_response("not json")
      expect(anomalies).to eq([])
    end
  end
end
