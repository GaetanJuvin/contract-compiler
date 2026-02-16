# Contract Compiler Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Ruby CLI that parses contracts (text/PDF), constructs a two-layer DAG via symbolic reasoning, and uses OpenAI to detect anomalies.

**Architecture:** Pipeline: Parser -> Clause Extractor -> Semantic Extractor -> DAG Builder -> Symbolic Reasoner -> OpenAI Analyzer -> Reporter. Each stage is a standalone class with clear input/output boundaries.

**Tech Stack:** Ruby 3.0+, light-openai-lib, pdf-reader, rspec, optparse (stdlib)

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Gemfile`
- Create: `lib/contract_compiler.rb`
- Create: `.rspec`
- Create: `spec/spec_helper.rb`

**Step 1: Create Gemfile**

```ruby
# Gemfile
source "https://rubygems.org"

gem "light-openai-lib"
gem "pdf-reader"

group :test do
  gem "rspec", "~> 3.0"
end
```

**Step 2: Create lib/contract_compiler.rb (top-level require file)**

```ruby
# lib/contract_compiler.rb
module ContractCompiler
end

require_relative "contract_compiler/dag/node"
require_relative "contract_compiler/dag/edge"
require_relative "contract_compiler/dag/graph"
require_relative "contract_compiler/parser"
require_relative "contract_compiler/clause_extractor"
require_relative "contract_compiler/semantic_extractor"
require_relative "contract_compiler/reasoner"
require_relative "contract_compiler/analyzer"
require_relative "contract_compiler/reporter"
require_relative "contract_compiler/cli"
```

**Step 3: Create .rspec**

```
--require spec_helper
--format documentation
--color
```

**Step 4: Create spec/spec_helper.rb**

```ruby
# spec/spec_helper.rb
require "contract_compiler"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
end
```

**Step 5: Run bundle install**

Run: `bundle install`
Expected: Successful installation of all gems.

**Step 6: Commit**

```bash
git add Gemfile Gemfile.lock lib/contract_compiler.rb .rspec spec/spec_helper.rb
git commit -m "feat: project scaffolding with dependencies and test setup"
```

---

### Task 2: DAG Nodes

**Files:**
- Create: `lib/contract_compiler/dag/node.rb`
- Create: `spec/dag/node_spec.rb`

**Step 1: Write the failing tests**

```ruby
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
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/dag/node_spec.rb`
Expected: FAIL — classes not defined yet.

**Step 3: Write minimal implementation**

```ruby
# lib/contract_compiler/dag/node.rb
module ContractCompiler
  module DAG
    class ClauseNode
      attr_reader :id, :title, :body, :level, :parent_id

      def initialize(id:, title:, body:, level:, parent_id:)
        @id = id
        @title = title
        @body = body
        @level = level
        @parent_id = parent_id
      end

      def type
        :clause
      end

      def to_hash
        { id: @id, type: type, title: @title, body: @body, level: @level, parent_id: @parent_id }
      end
    end

    class ObligationNode
      attr_reader :id, :party, :action, :target_party, :temporal

      def initialize(id:, party:, action:, target_party:, temporal: nil)
        @id = id
        @party = party
        @action = action
        @target_party = target_party
        @temporal = temporal
      end

      def type
        :obligation
      end

      def to_hash
        { id: @id, type: type, party: @party, action: @action, target_party: @target_party, temporal: @temporal }
      end
    end

    class RightNode
      attr_reader :id, :party, :entitlement, :scope

      def initialize(id:, party:, entitlement:, scope: nil)
        @id = id
        @party = party
        @entitlement = entitlement
        @scope = scope
      end

      def type
        :right
      end

      def to_hash
        { id: @id, type: type, party: @party, entitlement: @entitlement, scope: @scope }
      end
    end

    class ConditionNode
      attr_reader :id, :trigger, :consequence, :referenced_clauses

      def initialize(id:, trigger:, consequence:, referenced_clauses: [])
        @id = id
        @trigger = trigger
        @consequence = consequence
        @referenced_clauses = referenced_clauses
      end

      def type
        :condition
      end

      def to_hash
        { id: @id, type: type, trigger: @trigger, consequence: @consequence, referenced_clauses: @referenced_clauses }
      end
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/dag/node_spec.rb`
Expected: All PASS.

**Step 5: Commit**

```bash
git add lib/contract_compiler/dag/node.rb spec/dag/node_spec.rb
git commit -m "feat: DAG node types (clause, obligation, right, condition)"
```

---

### Task 3: DAG Edges

**Files:**
- Create: `lib/contract_compiler/dag/edge.rb`
- Create: `spec/dag/edge_spec.rb`

**Step 1: Write the failing tests**

```ruby
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
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/dag/edge_spec.rb`
Expected: FAIL.

**Step 3: Write minimal implementation**

```ruby
# lib/contract_compiler/dag/edge.rb
module ContractCompiler
  module DAG
    class Edge
      VALID_TYPES = %i[references derived_from depends_on conflicts_with].freeze

      attr_reader :from, :to, :type

      def initialize(from:, to:, type:)
        raise ArgumentError, "Invalid edge type: #{type}" unless VALID_TYPES.include?(type)

        @from = from
        @to = to
        @type = type
      end

      def to_hash
        { from: @from, to: @to, type: @type }
      end
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/dag/edge_spec.rb`
Expected: All PASS.

**Step 5: Commit**

```bash
git add lib/contract_compiler/dag/edge.rb spec/dag/edge_spec.rb
git commit -m "feat: DAG edge with type validation"
```

---

### Task 4: DAG Graph

**Files:**
- Create: `lib/contract_compiler/dag/graph.rb`
- Create: `spec/dag/graph_spec.rb`

**Step 1: Write the failing tests**

```ruby
# spec/dag/graph_spec.rb
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
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/dag/graph_spec.rb`
Expected: FAIL.

**Step 3: Write minimal implementation**

```ruby
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
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/dag/graph_spec.rb`
Expected: All PASS.

**Step 5: Commit**

```bash
git add lib/contract_compiler/dag/graph.rb spec/dag/graph_spec.rb
git commit -m "feat: DAG graph with cycle detection, topological sort, path finding"
```

---

### Task 5: Parser

**Files:**
- Create: `lib/contract_compiler/parser.rb`
- Create: `spec/parser_spec.rb`
- Create: `spec/fixtures/sample.txt`

**Step 1: Create test fixture**

```text
# spec/fixtures/sample.txt
SERVICES AGREEMENT

1. Definitions
In this Agreement, the following terms shall have the meanings set forth below.

2. Obligations
2.1 The Seller shall deliver the goods within 30 days of the order date.
2.2 The Buyer must pay the invoice within 15 days of delivery.

3. Rights
The Buyer may inspect the goods at any time during business hours.

4. Conditions
If delivery is late by more than 10 days, the Buyer is entitled to a 5% discount.
Subject to clause 2.1, the Seller shall not be liable for delays caused by force majeure.

5. Termination
Either party may terminate this Agreement by providing 30 days written notice.
```

**Step 2: Write the failing tests**

```ruby
# spec/parser_spec.rb
require "spec_helper"

RSpec.describe ContractCompiler::Parser do
  describe ".parse" do
    it "reads a text file" do
      text = described_class.parse("spec/fixtures/sample.txt")
      expect(text).to include("SERVICES AGREEMENT")
      expect(text).to include("Seller shall deliver")
    end

    it "raises for unsupported file type" do
      expect { described_class.parse("file.docx") }.to raise_error(ArgumentError, /unsupported file type/i)
    end

    it "raises for missing file" do
      expect { described_class.parse("nonexistent.txt") }.to raise_error(Errno::ENOENT)
    end

    it "reads a PDF file" do
      # Integration test — only runs if fixture exists
      skip "No PDF fixture" unless File.exist?("spec/fixtures/sample.pdf")
      text = described_class.parse("spec/fixtures/sample.pdf")
      expect(text).to be_a(String)
      expect(text.length).to be > 0
    end
  end
end
```

**Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/parser_spec.rb`
Expected: FAIL.

**Step 4: Write minimal implementation**

```ruby
# lib/contract_compiler/parser.rb
require "pdf-reader"

module ContractCompiler
  class Parser
    SUPPORTED_EXTENSIONS = %w[.txt .pdf].freeze

    def self.parse(file_path)
      ext = File.extname(file_path).downcase
      raise ArgumentError, "Unsupported file type: #{ext}" unless SUPPORTED_EXTENSIONS.include?(ext)

      case ext
      when ".txt"
        File.read(file_path)
      when ".pdf"
        parse_pdf(file_path)
      end
    end

    def self.parse_pdf(file_path)
      reader = PDF::Reader.new(file_path)
      reader.pages.map(&:text).join("\n\n")
    end

    private_class_method :parse_pdf
  end
end
```

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/parser_spec.rb`
Expected: All PASS (PDF test skipped).

**Step 6: Commit**

```bash
git add lib/contract_compiler/parser.rb spec/parser_spec.rb spec/fixtures/sample.txt
git commit -m "feat: parser for text and PDF files"
```

---

### Task 6: Clause Extractor

**Files:**
- Create: `lib/contract_compiler/clause_extractor.rb`
- Create: `spec/clause_extractor_spec.rb`

**Step 1: Write the failing tests**

```ruby
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
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/clause_extractor_spec.rb`
Expected: FAIL.

**Step 3: Write minimal implementation**

```ruby
# lib/contract_compiler/clause_extractor.rb
module ContractCompiler
  class ClauseExtractor
    # Matches: "1. Title", "1.1 Title", "Article I", "ARTICLE 1"
    NUMBERED_SECTION = /^(\d+(?:\.\d+)*)\.\s+(.+)$/
    ARTICLE_SECTION = /^(Article\s+[IVXLCDM\d]+)[:\.\s]*(.*)$/i

    def self.extract(text)
      clauses = try_numbered_extraction(text)
      clauses = try_paragraph_fallback(text) if clauses.empty?
      clauses
    end

    def self.try_numbered_extraction(text)
      lines = text.lines
      sections = []
      current_number = nil
      current_title = nil
      current_body_lines = []
      current_level = nil

      lines.each do |line|
        if (match = line.match(NUMBERED_SECTION))
          if current_number
            sections << { number: current_number, title: current_title, body: current_body_lines.join.strip, level: current_level }
          end
          current_number = match[1]
          current_title = match[2].strip
          current_body_lines = []
          current_level = current_number.count(".") + 1
        elsif (match = line.match(ARTICLE_SECTION))
          if current_number
            sections << { number: current_number, title: current_title, body: current_body_lines.join.strip, level: current_level }
          end
          current_number = match[1]
          current_title = match[2].strip
          current_body_lines = []
          current_level = 1
        else
          current_body_lines << line if current_number
        end
      end

      if current_number
        sections << { number: current_number, title: current_title, body: current_body_lines.join.strip, level: current_level }
      end

      build_clause_nodes(sections)
    end

    def self.try_paragraph_fallback(text)
      paragraphs = text.split(/\n\s*\n/).map(&:strip).reject(&:empty?)
      paragraphs.each_with_index.map do |para, i|
        DAG::ClauseNode.new(
          id: "clause_#{i + 1}",
          title: "Section #{i + 1}",
          body: para,
          level: 1,
          parent_id: nil
        )
      end
    end

    def self.build_clause_nodes(sections)
      parent_stack = []

      sections.map.with_index do |sec, i|
        while parent_stack.any? && parent_stack.last[:level] >= sec[:level]
          parent_stack.pop
        end
        parent_id = parent_stack.last&.dig(:id)
        id = "clause_#{i + 1}"

        parent_stack.push({ id: id, level: sec[:level] })

        DAG::ClauseNode.new(
          id: id,
          title: sec[:title],
          body: sec[:body],
          level: sec[:level],
          parent_id: parent_id
        )
      end
    end

    private_class_method :try_numbered_extraction, :try_paragraph_fallback, :build_clause_nodes
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/clause_extractor_spec.rb`
Expected: All PASS.

**Step 5: Commit**

```bash
git add lib/contract_compiler/clause_extractor.rb spec/clause_extractor_spec.rb
git commit -m "feat: clause extractor with numbered, article, and fallback parsing"
```

---

### Task 7: Semantic Extractor

**Files:**
- Create: `lib/contract_compiler/semantic_extractor.rb`
- Create: `spec/semantic_extractor_spec.rb`

**Step 1: Write the failing tests**

```ruby
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
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/semantic_extractor_spec.rb`
Expected: FAIL.

**Step 3: Write minimal implementation**

```ruby
# lib/contract_compiler/semantic_extractor.rb
module ContractCompiler
  class SemanticExtractor
    OBLIGATION_PATTERNS = [
      /(?:the\s+)?(\w+)\s+(?:shall|must|agrees?\s+to|is\s+required\s+to)\s+(.+?)(?:\.\s|$)/i,
    ].freeze

    RIGHT_PATTERNS = [
      /(?:the\s+)?(\w+)\s+(?:may|is\s+entitled\s+to|has\s+the\s+right\s+to)\s+(.+?)(?:\.\s|$)/i,
    ].freeze

    CONDITION_PATTERNS = [
      /(?:if|provided\s+that|subject\s+to|upon)\s+(.+?),\s*(.+?)(?:\.\s|$)/i,
    ].freeze

    TEMPORAL_PATTERN = /(?:within|before|after|no\s+later\s+than)\s+(\d+\s+\w+)/i

    PARTY_PATTERN = /(?:the\s+)?(#{common_party_words.join("|")})/i

    def self.common_party_words
      %w[Seller Buyer Company Employee Contractor Client Landlord Tenant Licensor Licensee Provider Customer Vendor Supplier Lessee Lessor Borrower Lender]
    end

    def self.extract_parties(text)
      parties = []
      common_party_words.each do |word|
        parties << word if text.match?(/\b#{word}\b/i)
      end
      parties.uniq
    end

    def self.extract(clauses)
      nodes = []
      edges = []
      counters = { obligation: 0, right: 0, condition: 0 }

      clauses.each do |clause|
        extract_obligations(clause, nodes, edges, counters)
        extract_rights(clause, nodes, edges, counters)
        extract_conditions(clause, nodes, edges, counters)
      end

      { nodes: nodes, edges: edges }
    end

    def self.extract_obligations(clause, nodes, edges, counters)
      OBLIGATION_PATTERNS.each do |pattern|
        clause.body.scan(pattern) do |party, action|
          counters[:obligation] += 1
          id = "obl_#{counters[:obligation]}"
          temporal = action.match(TEMPORAL_PATTERN)&.send(:[], 0)
          target = detect_target_party(action)

          nodes << DAG::ObligationNode.new(
            id: id,
            party: party.strip,
            action: action.strip,
            target_party: target,
            temporal: temporal
          )
          edges << { from: clause.id, to: id, type: :derived_from }
        end
      end
    end

    def self.extract_rights(clause, nodes, edges, counters)
      RIGHT_PATTERNS.each do |pattern|
        clause.body.scan(pattern) do |party, entitlement|
          counters[:right] += 1
          id = "right_#{counters[:right]}"

          nodes << DAG::RightNode.new(
            id: id,
            party: party.strip,
            entitlement: entitlement.strip
          )
          edges << { from: clause.id, to: id, type: :derived_from }
        end
      end
    end

    def self.extract_conditions(clause, nodes, edges, counters)
      CONDITION_PATTERNS.each do |pattern|
        clause.body.scan(pattern) do |trigger, consequence|
          counters[:condition] += 1
          id = "cond_#{counters[:condition]}"
          refs = extract_clause_references(trigger + " " + consequence)

          nodes << DAG::ConditionNode.new(
            id: id,
            trigger: trigger.strip,
            consequence: consequence.strip,
            referenced_clauses: refs
          )
          edges << { from: clause.id, to: id, type: :derived_from }
        end
      end
    end

    def self.detect_target_party(text)
      common_party_words.each do |word|
        return word if text.match?(/\b#{word}\b/i)
      end
      nil
    end

    def self.extract_clause_references(text)
      refs = []
      text.scan(/(?:clause|section|article)\s+(\d+(?:\.\d+)*)/i) do |num|
        refs << num[0]
      end
      refs
    end

    private_class_method :extract_obligations, :extract_rights, :extract_conditions,
                         :detect_target_party, :extract_clause_references
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/semantic_extractor_spec.rb`
Expected: All PASS.

**Step 5: Commit**

```bash
git add lib/contract_compiler/semantic_extractor.rb spec/semantic_extractor_spec.rb
git commit -m "feat: semantic extractor for obligations, rights, conditions"
```

---

### Task 8: Symbolic Reasoner

**Files:**
- Create: `lib/contract_compiler/reasoner.rb`
- Create: `spec/reasoner_spec.rb`

**Step 1: Write the failing tests**

```ruby
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
      # No edges from this condition

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
      # Seller has obligations but no rights

      anomalies = described_class.analyze(graph)
      types = anomalies.map { |a| a[:type] }
      expect(types).to include(:missing_reciprocity)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/reasoner_spec.rb`
Expected: FAIL.

**Step 3: Write minimal implementation**

```ruby
# lib/contract_compiler/reasoner.rb
module ContractCompiler
  class Reasoner
    def self.analyze(graph)
      anomalies = []
      anomalies.concat(check_circular_dependencies(graph))
      anomalies.concat(check_contradictory_obligations(graph))
      anomalies.concat(check_orphaned_obligations(graph))
      anomalies.concat(check_dangling_conditions(graph))
      anomalies.concat(check_missing_reciprocity(graph))
      anomalies.concat(check_unmatched_references(graph))
      anomalies
    end

    def self.check_circular_dependencies(graph)
      cycles = graph.cycle_detect
      cycles.map do |cycle|
        {
          type: :circular_dependency,
          severity: :critical,
          description: "Circular dependency detected: #{cycle.join(" -> ")}",
          involved_nodes: cycle
        }
      end
    end

    def self.check_contradictory_obligations(graph)
      anomalies = []
      obligations = graph.nodes.select { |n| n.type == :obligation }

      obligations.combination(2).each do |o1, o2|
        next unless o1.party.downcase == o2.party.downcase

        a1 = o1.action.downcase.gsub(/\bnot\s+/, "")
        a2 = o2.action.downcase.gsub(/\bnot\s+/, "")
        negated1 = o1.action.downcase.include?("not ")
        negated2 = o2.action.downcase.include?("not ")

        if similar_actions?(a1, a2) && negated1 != negated2
          anomalies << {
            type: :contradictory_obligations,
            severity: :critical,
            description: "#{o1.party} has contradictory obligations: '#{o1.action}' vs '#{o2.action}'",
            involved_nodes: [o1.id, o2.id]
          }
        end
      end

      anomalies
    end

    def self.check_orphaned_obligations(graph)
      graph.nodes
        .select { |n| n.type == :obligation && (n.party.nil? || n.party.strip.empty?) }
        .map do |node|
          {
            type: :orphaned_obligation,
            severity: :high,
            description: "Obligation '#{node.action}' has no associated party",
            involved_nodes: [node.id]
          }
        end
    end

    def self.check_dangling_conditions(graph)
      graph.nodes
        .select { |n| n.type == :condition }
        .select { |n| graph.edges.none? { |e| e.from == n.id && e.type != :derived_from } && graph.edges.none? { |e| e.to == n.id && e.type == :depends_on } }
        .map do |node|
          {
            type: :dangling_condition,
            severity: :medium,
            description: "Condition '#{node.trigger}' is defined but never referenced by any obligation or right",
            involved_nodes: [node.id]
          }
        end
    end

    def self.check_missing_reciprocity(graph)
      anomalies = []
      obligations = graph.nodes.select { |n| n.type == :obligation }
      rights = graph.nodes.select { |n| n.type == :right }

      parties_with_obligations = obligations.map { |o| o.party.downcase }.uniq
      parties_with_rights = rights.map { |r| r.party.downcase }.uniq

      parties_with_obligations.each do |party|
        unless parties_with_rights.include?(party)
          anomalies << {
            type: :missing_reciprocity,
            severity: :medium,
            description: "Party '#{party}' has obligations but no corresponding rights",
            involved_nodes: obligations.select { |o| o.party.downcase == party }.map(&:id)
          }
        end
      end

      anomalies
    end

    def self.check_unmatched_references(graph)
      anomalies = []
      clause_ids = graph.nodes.select { |n| n.type == :clause }.map(&:id)

      graph.nodes.select { |n| n.type == :condition }.each do |cond|
        cond.referenced_clauses.each do |ref|
          matching = clause_ids.any? { |cid| cid.include?(ref) }
          unless matching
            anomalies << {
              type: :unmatched_reference,
              severity: :high,
              description: "Condition '#{cond.trigger}' references clause '#{ref}' which does not exist",
              involved_nodes: [cond.id]
            }
          end
        end
      end

      anomalies
    end

    def self.similar_actions?(a1, a2)
      words1 = a1.split(/\s+/).to_set
      words2 = a2.split(/\s+/).to_set
      intersection = words1 & words2
      union = words1 | words2
      return false if union.empty?

      (intersection.size.to_f / union.size) > 0.5
    end

    private_class_method :check_circular_dependencies, :check_contradictory_obligations,
                         :check_orphaned_obligations, :check_dangling_conditions,
                         :check_missing_reciprocity, :check_unmatched_references,
                         :similar_actions?
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/reasoner_spec.rb`
Expected: All PASS.

**Step 5: Commit**

```bash
git add lib/contract_compiler/reasoner.rb spec/reasoner_spec.rb
git commit -m "feat: symbolic reasoner with 6 anomaly detection rules"
```

---

### Task 9: OpenAI Analyzer

**Files:**
- Create: `lib/contract_compiler/analyzer.rb`
- Create: `spec/analyzer_spec.rb`

**Step 1: Write the failing tests**

```ruby
# spec/analyzer_spec.rb
require "spec_helper"

RSpec.describe ContractCompiler::Analyzer do
  describe ".analyze" do
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
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/analyzer_spec.rb`
Expected: FAIL.

**Step 3: Write minimal implementation**

```ruby
# lib/contract_compiler/analyzer.rb
require "light/openai"
require "json"

module ContractCompiler
  class Analyzer
    SYSTEM_PROMPT = <<~PROMPT
      You are a contract analysis expert. You will receive:
      1. A contract's text
      2. A DAG (directed acyclic graph) representing the contract's structure and semantics
      3. Anomalies already detected by a symbolic reasoner

      Your job is to find ADDITIONAL anomalies that rule-based analysis cannot catch:
      - Ambiguous language: vague terms without definition ("reasonable", "timely", "best efforts")
      - Industry-standard gaps: missing clauses typical for the contract type (force majeure, indemnification, governing law, dispute resolution)
      - Asymmetric terms: unfairly one-sided provisions
      - Inconsistent definitions: same term used differently across clauses
      - Hidden implications: combinations of clauses that create unintended consequences

      Respond with JSON in this exact format:
      {
        "anomalies": [
          {
            "type": "ambiguous_language|industry_standard_gap|asymmetric_terms|inconsistent_definitions|hidden_implications",
            "severity": "low|medium|high|critical",
            "description": "Clear explanation of the anomaly",
            "involved_clauses": ["clause identifiers"],
            "recommendation": "How to fix it"
          }
        ]
      }

      Do NOT repeat anomalies already found by the symbolic reasoner.
    PROMPT

    def self.analyze(graph_hash:, original_text:, symbolic_anomalies:)
      client = Light::OpenAI::Client.new(
        api_key: ENV.fetch("OPENAI_API_KEY")
      )

      prompt = build_prompt(
        graph_hash: graph_hash,
        original_text: original_text,
        symbolic_anomalies: symbolic_anomalies
      )

      response = client.chat(
        model: "gpt-5.2",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: prompt }
        ],
        temperature: 0.2,
        response_format: { type: "json_object" }
      )

      raw = response.dig("choices", 0, "message", "content")
      parse_response(raw)
    end

    def self.build_prompt(graph_hash:, original_text:, symbolic_anomalies:)
      <<~PROMPT
        ## Contract Text

        #{original_text}

        ## Contract DAG Structure

        ```json
        #{JSON.pretty_generate(graph_hash)}
        ```

        ## Already Detected Anomalies (by symbolic reasoner)

        #{symbolic_anomalies.empty? ? "None" : JSON.pretty_generate(symbolic_anomalies)}

        Please analyze this contract and return any additional anomalies you find.
      PROMPT
    end

    def self.parse_response(raw)
      data = JSON.parse(raw)
      (data["anomalies"] || []).map do |a|
        {
          type: a["type"]&.to_sym,
          severity: a["severity"]&.to_sym,
          description: a["description"],
          involved_nodes: a["involved_clauses"] || [],
          recommendation: a["recommendation"],
          source: :ai
        }
      end
    rescue JSON::ParserError
      []
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/analyzer_spec.rb`
Expected: All PASS.

**Step 5: Commit**

```bash
git add lib/contract_compiler/analyzer.rb spec/analyzer_spec.rb
git commit -m "feat: OpenAI analyzer with structured prompt and JSON response parsing"
```

---

### Task 10: Reporter

**Files:**
- Create: `lib/contract_compiler/reporter.rb`
- Create: `spec/reporter_spec.rb`

**Step 1: Write the failing tests**

```ruby
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
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/reporter_spec.rb`
Expected: FAIL.

**Step 3: Write minimal implementation**

```ruby
# lib/contract_compiler/reporter.rb
require "json"

module ContractCompiler
  class Reporter
    SEVERITY_ORDER = %i[critical high medium low].freeze

    def self.format_text(anomalies:, metadata:)
      lines = []
      lines << "Contract Analysis Report"
      lines << "=" * 60
      lines << "Source: #{metadata[:source_file]} (#{metadata[:clause_count]} clauses, #{metadata[:party_count]} parties)"
      lines << ""

      grouped = group_by_severity(anomalies)
      counters = { critical: 0, high: 0, medium: 0, low: 0 }

      SEVERITY_ORDER.each do |severity|
        items = grouped[severity] || []
        next if items.empty?

        counters[severity] = items.length
        lines << "#{severity.to_s.upcase} (#{items.length})"

        items.each_with_index do |anomaly, i|
          prefix = severity_prefix(severity)
          lines << "  [#{prefix}#{i + 1}] #{anomaly[:description]}"
          lines << "       Recommendation: #{anomaly[:recommendation]}" if anomaly[:recommendation]
        end

        lines << ""
      end

      critical_high = counters[:critical] + counters[:high]
      total = anomalies.length
      lines << "Summary: #{critical_high} critical/high, #{counters[:medium]} medium, #{counters[:low]} low anomalies found."

      lines.join("\n")
    end

    def self.format_json(anomalies:, metadata:, graph_hash:)
      JSON.pretty_generate({
        metadata: metadata,
        graph: graph_hash,
        anomalies: anomalies.map { |a| stringify_keys(a) },
        summary: {
          total: anomalies.length,
          by_severity: count_by_severity(anomalies)
        }
      })
    end

    def self.group_by_severity(anomalies)
      anomalies.group_by { |a| a[:severity] }
    end

    def self.severity_prefix(severity)
      { critical: "C", high: "H", medium: "M", low: "L" }[severity]
    end

    def self.count_by_severity(anomalies)
      counts = Hash.new(0)
      anomalies.each { |a| counts[a[:severity].to_s] += 1 }
      counts
    end

    def self.stringify_keys(hash)
      hash.transform_keys(&:to_s).transform_values do |v|
        v.is_a?(Symbol) ? v.to_s : v
      end
    end

    private_class_method :group_by_severity, :severity_prefix, :count_by_severity, :stringify_keys
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/reporter_spec.rb`
Expected: All PASS.

**Step 5: Commit**

```bash
git add lib/contract_compiler/reporter.rb spec/reporter_spec.rb
git commit -m "feat: reporter with text and JSON output formats"
```

---

### Task 11: CLI

**Files:**
- Create: `lib/contract_compiler/cli.rb`
- Create: `bin/contract-compiler`
- Create: `spec/cli_spec.rb`

**Step 1: Write the failing tests**

```ruby
# spec/cli_spec.rb
require "spec_helper"

RSpec.describe ContractCompiler::CLI do
  describe ".parse_options" do
    it "parses --json flag" do
      options = described_class.parse_options(["--json", "contract.txt"])
      expect(options[:json]).to be true
      expect(options[:file]).to eq("contract.txt")
    end

    it "parses --verbose flag" do
      options = described_class.parse_options(["--verbose", "contract.txt"])
      expect(options[:verbose]).to be true
    end

    it "defaults to text output" do
      options = described_class.parse_options(["contract.txt"])
      expect(options[:json]).to be false
      expect(options[:verbose]).to be false
    end

    it "raises if no file provided" do
      expect { described_class.parse_options([]) }.to raise_error(ArgumentError, /file/i)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/cli_spec.rb`
Expected: FAIL.

**Step 3: Write minimal implementation**

```ruby
# lib/contract_compiler/cli.rb
require "optparse"

module ContractCompiler
  class CLI
    def self.parse_options(argv)
      options = { json: false, verbose: false }

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: contract-compiler [options] FILE"

        opts.on("--json", "Output as JSON") { options[:json] = true }
        opts.on("--verbose", "Show DAG structure and extraction details") { options[:verbose] = true }
        opts.on("-h", "--help", "Show help") do
          puts opts
          exit
        end
      end

      remaining = parser.parse(argv)
      raise ArgumentError, "File argument is required" if remaining.empty?

      options[:file] = remaining.first
      options
    end

    def self.run(argv)
      options = parse_options(argv)

      $stderr.puts "Parsing #{options[:file]}..." if options[:verbose]
      text = Parser.parse(options[:file])

      $stderr.puts "Extracting clauses..." if options[:verbose]
      clauses = ClauseExtractor.extract(text)

      $stderr.puts "Extracting semantics..." if options[:verbose]
      semantic_result = SemanticExtractor.extract(clauses)
      parties = SemanticExtractor.extract_parties(text)

      $stderr.puts "Building DAG..." if options[:verbose]
      graph = build_graph(clauses, semantic_result)

      if options[:verbose]
        $stderr.puts "DAG: #{graph.nodes.length} nodes, #{graph.edges.length} edges"
      end

      $stderr.puts "Running symbolic reasoner..." if options[:verbose]
      symbolic_anomalies = Reasoner.analyze(graph)

      $stderr.puts "Calling OpenAI analyzer..." if options[:verbose]
      ai_anomalies = Analyzer.analyze(
        graph_hash: graph.to_hash,
        original_text: text,
        symbolic_anomalies: symbolic_anomalies
      )

      all_anomalies = symbolic_anomalies.map { |a| a.merge(source: :symbolic) } +
                      ai_anomalies

      metadata = {
        source_file: options[:file],
        clause_count: clauses.length,
        party_count: parties.length
      }

      if options[:json]
        puts Reporter.format_json(anomalies: all_anomalies, metadata: metadata, graph_hash: graph.to_hash)
      else
        puts Reporter.format_text(anomalies: all_anomalies, metadata: metadata)
      end
    end

    def self.build_graph(clauses, semantic_result)
      graph = DAG::Graph.new

      clauses.each { |c| graph.add_node(c) }
      semantic_result[:nodes].each { |n| graph.add_node(n) }
      semantic_result[:edges].each { |e| graph.add_edge(from: e[:from], to: e[:to], type: e[:type]) }

      # Add cross-clause reference edges
      clauses.each do |clause|
        clauses.each do |other|
          next if clause.id == other.id
          if clause.body.match?(/(?:clause|section)\s+#{Regexp.escape(other.title)}/i)
            graph.add_edge(from: clause.id, to: other.id, type: :references)
          end
        end
      end

      graph
    end

    private_class_method :build_graph
  end
end
```

**Step 4: Create bin/contract-compiler**

```ruby
#!/usr/bin/env ruby
require_relative "../lib/contract_compiler"

ContractCompiler::CLI.run(ARGV)
```

Make it executable: `chmod +x bin/contract-compiler`

**Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/cli_spec.rb`
Expected: All PASS.

**Step 6: Commit**

```bash
git add lib/contract_compiler/cli.rb bin/contract-compiler spec/cli_spec.rb
git commit -m "feat: CLI with --json and --verbose flags"
```

---

### Task 12: Integration Test

**Files:**
- Create: `spec/integration_spec.rb`

**Step 1: Write the integration test**

```ruby
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
```

**Step 2: Run integration test**

Run: `bundle exec rspec spec/integration_spec.rb`
Expected: All PASS.

**Step 3: Run full test suite**

Run: `bundle exec rspec`
Expected: All PASS.

**Step 4: Commit**

```bash
git add spec/integration_spec.rb
git commit -m "feat: integration test covering full pipeline"
```

---

### Task 13: Final Cleanup

**Step 1: Run full test suite one more time**

Run: `bundle exec rspec`
Expected: All PASS.

**Step 2: Test CLI manually**

Run: `bundle exec ruby bin/contract-compiler spec/fixtures/sample.txt --verbose`
Expected: Fails at OpenAI step (no API key), but all prior steps should print verbose output.

Run: `OPENAI_API_KEY=test bundle exec ruby bin/contract-compiler spec/fixtures/sample.txt --verbose 2>&1 || true`
Expected: Verbose output showing parsing, extraction, and DAG building before API failure.

**Step 3: Final commit**

```bash
git add -A
git commit -m "chore: final cleanup and verification"
```
