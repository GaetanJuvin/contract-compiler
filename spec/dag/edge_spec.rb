# spec/dag/edge_spec.rb
require "spec_helper"

RSpec.describe ContractCompiler::DAG::Edge do
  it "stores edge attributes" do
    edge = described_class.new(from: "clause_1", to: "clause_2", type: :references)

    expect(edge.from).to eq("clause_1")
    expect(edge.to).to eq("clause_2")
    expect(edge.type).to eq(:references)
  end

  it "validates edge type" do
    expect {
      described_class.new(from: "a", to: "b", type: :invalid)
    }.to raise_error(ArgumentError, /invalid edge type/i)
  end

  it "converts to hash" do
    edge = described_class.new(from: "a", to: "b", type: :depends_on)
    expect(edge.to_hash).to eq({ from: "a", to: "b", type: :depends_on })
  end

  described_class::VALID_TYPES.each do |t|
    it "accepts type #{t}" do
      edge = described_class.new(from: "a", to: "b", type: t)
      expect(edge.type).to eq(t)
    end
  end
end
