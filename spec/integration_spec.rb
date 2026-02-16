# spec/integration_spec.rb
require "spec_helper"

RSpec.describe "Integration: full pipeline (without OpenAI)" do
  let(:text) { File.read("spec/fixtures/sample.txt") }

  it "runs the full pipeline from text to report" do
    # Parse
    clauses = ContractCompiler::ClauseExtractor.extract(text)
    expect(clauses).not_to be_empty

    # Semantic extraction
    semantic = ContractCompiler::SemanticExtractor.extract(clauses)
    expect(semantic[:nodes]).not_to be_empty

    # Build graph
    graph = ContractCompiler::DAG::Graph.new
    clauses.each { |c| graph.add_node(c) }
    semantic[:nodes].each { |n| graph.add_node(n) }
    semantic[:edges].each { |e| graph.add_edge(from: e[:from], to: e[:to], type: e[:type]) }

    expect(graph.nodes.length).to be > clauses.length
    expect(graph.edges.length).to be > 0

    # Symbolic reasoning
    anomalies = ContractCompiler::Reasoner.analyze(graph)
    expect(anomalies).to be_an(Array)

    # Report (text)
    parties = ContractCompiler::SemanticExtractor.extract_parties(text)
    metadata = { source_file: "sample.txt", clause_count: clauses.length, party_count: parties.length }
    report = ContractCompiler::Reporter.format_text(anomalies: anomalies, metadata: metadata)
    expect(report).to include("Contract Analysis Report")
    expect(report).to include("sample.txt")

    # Report (JSON)
    json = ContractCompiler::Reporter.format_json(anomalies: anomalies, metadata: metadata, graph_hash: graph.to_hash)
    parsed = JSON.parse(json)
    expect(parsed).to have_key("metadata")
    expect(parsed).to have_key("graph")
    expect(parsed).to have_key("anomalies")
  end
end
