# spec/clause_extractor_spec.rb
require "spec_helper"

RSpec.describe ContractCompiler::ClauseExtractor do
  let(:text) { File.read("spec/fixtures/sample.txt") }

  describe ".extract" do
    it "returns an array of ClauseNodes" do
      clauses = described_class.extract(text)
      expect(clauses).to all(be_a(ContractCompiler::DAG::ClauseNode))
    end

    it "extracts numbered sections" do
      clauses = described_class.extract(text)
      titles = clauses.map(&:title)
      expect(titles).to include("Definitions")
      expect(titles).to include("Obligations")
      expect(titles).to include("Rights")
      expect(titles).to include("Termination")
    end

    it "detects nesting levels" do
      clauses = described_class.extract(text)
      top_level = clauses.select { |c| c.level == 1 }
      nested = clauses.select { |c| c.level == 2 }
      expect(top_level.length).to be >= 5
      expect(nested.length).to be >= 2
    end

    it "sets parent_id for nested clauses" do
      clauses = described_class.extract(text)
      nested = clauses.select { |c| c.level == 2 }
      nested.each do |c|
        expect(c.parent_id).not_to be_nil
      end
    end

    it "falls back to paragraph splitting for unstructured text" do
      plain = "First paragraph about terms.\n\nSecond paragraph about obligations.\n\nThird paragraph about rights."
      clauses = described_class.extract(plain)
      expect(clauses.length).to eq(3)
      expect(clauses.first.title).to eq("Section 1")
    end
  end
end
