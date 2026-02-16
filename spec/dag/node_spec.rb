# spec/dag/node_spec.rb
require "spec_helper"

RSpec.describe ContractCompiler::DAG::ClauseNode do
  it "stores clause attributes" do
    node = described_class.new(
      id: "clause_1",
      title: "Definitions",
      body: "The following terms shall have the meanings set forth below.",
      level: 1,
      parent_id: nil
    )

    expect(node.id).to eq("clause_1")
    expect(node.title).to eq("Definitions")
    expect(node.body).to eq("The following terms shall have the meanings set forth below.")
    expect(node.level).to eq(1)
    expect(node.parent_id).to be_nil
    expect(node.type).to eq(:clause)
  end

  it "converts to hash" do
    node = described_class.new(id: "c1", title: "Title", body: "Body", level: 1, parent_id: nil)
    hash = node.to_hash

    expect(hash[:id]).to eq("c1")
    expect(hash[:type]).to eq(:clause)
    expect(hash[:title]).to eq("Title")
  end
end

RSpec.describe ContractCompiler::DAG::ObligationNode do
  it "stores obligation attributes" do
    node = described_class.new(
      id: "obl_1",
      party: "Seller",
      action: "deliver goods",
      target_party: "Buyer",
      temporal: "within 30 days"
    )

    expect(node.id).to eq("obl_1")
    expect(node.party).to eq("Seller")
    expect(node.action).to eq("deliver goods")
    expect(node.target_party).to eq("Buyer")
    expect(node.temporal).to eq("within 30 days")
    expect(node.type).to eq(:obligation)
  end
end

RSpec.describe ContractCompiler::DAG::RightNode do
  it "stores right attributes" do
    node = described_class.new(
      id: "right_1",
      party: "Buyer",
      entitlement: "inspect goods",
      scope: "at any time during business hours"
    )

    expect(node.type).to eq(:right)
    expect(node.party).to eq("Buyer")
    expect(node.entitlement).to eq("inspect goods")
  end
end

RSpec.describe ContractCompiler::DAG::ConditionNode do
  it "stores condition attributes" do
    node = described_class.new(
      id: "cond_1",
      trigger: "if delivery is late",
      consequence: "penalty applies",
      referenced_clauses: ["clause_3", "clause_5"]
    )

    expect(node.type).to eq(:condition)
    expect(node.trigger).to eq("if delivery is late")
    expect(node.referenced_clauses).to eq(["clause_3", "clause_5"])
  end
end
