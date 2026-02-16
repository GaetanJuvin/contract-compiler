# spec/semantic_extractor_spec.rb
require "spec_helper"

RSpec.describe ContractCompiler::SemanticExtractor do
  let(:text) { File.read("spec/fixtures/sample.txt") }
  let(:clauses) { ContractCompiler::ClauseExtractor.extract(text) }

  describe ".extract" do
    it "returns a hash with :nodes and :edges" do
      result = described_class.extract(clauses)
      expect(result).to have_key(:nodes)
      expect(result).to have_key(:edges)
    end

    it "extracts obligations" do
      result = described_class.extract(clauses)
      obligations = result[:nodes].select { |n| n.type == :obligation }
      expect(obligations.length).to be >= 2
      actions = obligations.map(&:action)
      expect(actions.any? { |a| a.include?("deliver") }).to be true
    end

    it "extracts rights" do
      result = described_class.extract(clauses)
      rights = result[:nodes].select { |n| n.type == :right }
      expect(rights.length).to be >= 1
      expect(rights.any? { |r| r.entitlement.include?("inspect") }).to be true
    end

    it "extracts conditions" do
      result = described_class.extract(clauses)
      conditions = result[:nodes].select { |n| n.type == :condition }
      expect(conditions.length).to be >= 1
    end

    it "creates derived_from edges linking semantic nodes to clauses" do
      result = described_class.extract(clauses)
      derived_edges = result[:edges].select { |e| e[:type] == :derived_from }
      expect(derived_edges.length).to eq(result[:nodes].length)
    end

    it "extracts parties from the text" do
      parties = described_class.extract_parties(text)
      expect(parties).to include("Seller")
      expect(parties).to include("Buyer")
    end
  end
end
