# Contract Compiler

A Ruby CLI tool that parses contracts (text/PDF), builds a two-layer DAG via symbolic reasoning, then uses OpenAI to detect anomalies. Targets all contract types: legal, financial/procurement, and general structured documents.

## How It Works

```
Input (txt/pdf)
    → Parser (extract raw text)
    → Clause Extractor (split into structural sections)
    → Semantic Extractor (obligations, rights, conditions, parties)
    → DAG Builder (two-layer graph: clause layer + semantic layer)
    → Symbolic Reasoner (rule-based anomaly detection on the DAG)
    → OpenAI Analyzer (feed DAG + original text to GPT for deeper anomalies)
    → Reporter (formatted text or JSON to stdout)
```

**Two-layer DAG:**
- **Structural layer** — clauses with nesting, cross-references
- **Semantic layer** — obligations ("shall"), rights ("may"), conditions ("if"), linked back to source clauses

**Two-stage anomaly detection:**
- **Symbolic reasoner** (deterministic) — circular dependencies, contradictory obligations, orphaned obligations, dangling conditions, missing reciprocity, unmatched references
- **OpenAI analyzer** (GPT-5.2) — ambiguous language, industry-standard gaps, asymmetric terms, inconsistent definitions, hidden implications

Output is compiler-style with `file:line:` references and colorized severity levels.

## Installation

```bash
git clone git@github.com:GaetanJuvin/contract-compiler.git
cd contract-compiler
bundle install
```

Requires Ruby 3.0+ and an OpenAI API key.

## Usage

```bash
export OPENAI_API_KEY=your-key-here

# Analyze a contract
bin/contract-compiler analyze contract.txt

# JSON output
bin/contract-compiler analyze --json contract.txt

# Verbose mode (shows DAG structure, extraction stats, timing)
bin/contract-compiler analyze --verbose contract.txt

# PDF input
bin/contract-compiler analyze contract.pdf
```

### Example Output

```
  Contract Analysis Report
  ========================================================
  Source: contract.txt (44 clauses, 6 parties)

  ✘ CRITICAL (1)
    contract.txt:15: contract.txt:87: [C1] Contradictory obligations...
       Recommendation: Remove or reconcile the conflicting clauses.

  ⚠ HIGH (3)
    contract.txt:42: [H1] Missing indemnification clause...
    contract.txt:50: contract.txt:52: [H2] IP assignment too broad...
    contract.txt:34: [H3] All information presumed confidential...

  ● MEDIUM (5)
    contract.txt:102: [M1] Dangling condition never referenced...
    ...

  ○ LOW (1)
    contract.txt:96: [L1] Venue may be burdensome for one party...

  Summary: 4 critical/high, 5 medium, 1 low anomalies found.
```

Colors auto-detect TTY — plain text when piped to a file or another command.

### Verbose Mode

```
  CONTRACT COMPILER  v0.4.2
  ==================================================

  [1/6] Parsing file  contract.txt ✓ 0ms
        12009 characters, 129 lines
  [2/6] Extracting clauses ✓ 0ms
        44 clauses found
          ├─ clause_1:3 EMPLOYMENT
            ├─ clause_2:5 Position. The Company hereby employs...
            ├─ clause_3:7 Full-Time Commitment...
  [3/6] Extracting semantics ✓ 2ms
        Obligations: 23  Rights: 2  Conditions: 7
        Parties: Company, Employee, Contractor
  [4/6] Building DAG ✓ 31ms
        Nodes: 76 (44 clause + 32 semantic)
        Edges: 32
          derived_from: 32
  [5/6] Running symbolic reasoner ✓ 3ms
        ⚠ MEDIUM L102 dangling_condition ...
        ⚠ MEDIUM L34,L38 missing_reciprocity ...
  [6/6] Calling OpenAI analyzer (gpt-5.2) ✓ 29.8s
        13 AI anomalies detected

  Done! 27 anomalies found in 29.8s
```

## Project Structure

```
contract-compiler/
├── bin/
│   └── contract-compiler          # CLI entrypoint
├── lib/
│   └── contract_compiler/
│       ├── cli.rb                 # Argument parsing, pipeline orchestration
│       ├── parser.rb              # Text/PDF extraction
│       ├── clause_extractor.rb    # Structural decomposition with line tracking
│       ├── semantic_extractor.rb  # Obligations/rights/conditions extraction
│       ├── dag/
│       │   ├── node.rb            # ClauseNode, ObligationNode, RightNode, ConditionNode
│       │   ├── edge.rb            # Edge types (references, derived_from, depends_on, conflicts_with)
│       │   └── graph.rb           # DAG construction, cycle detection, topological sort
│       ├── reasoner.rb            # 6 symbolic anomaly detection rules
│       ├── analyzer.rb            # OpenAI GPT-5.2 integration
│       └── reporter.rb            # Colorized text + JSON output
├── spec/                          # RSpec tests (55 examples)
├── tests-scenario/                # 72 test contracts
│   ├── contracts/                 # Service agreements (10 AI + 6 real)
│   ├── nda/                       # NDAs (10 AI + 5 real)
│   ├── leases/                    # Lease agreements (10 AI + 3 real)
│   ├── employment/                # Employment contracts (10 AI + 4 real)
│   └── procurement/               # Procurement contracts (10 AI + 4 real)
└── docs/plans/                    # Design & implementation docs
```

## Dependencies

- [`light-openai-lib`](https://github.com/GaetanJuvin/light-openai-lib) — OpenAI Chat Completions API wrapper
- `pdf-reader` — PDF text extraction (pure Ruby)
- `colorize` — Terminal color output

## Tests

```bash
bundle exec rspec
```

55 examples covering nodes, edges, graph algorithms, parser, extractors, reasoner, analyzer, reporter, CLI, and full integration.

## Test Scenarios

The `tests-scenario/` directory contains 72 contracts for testing:

- **50 AI-generated** contracts with deliberate anomalies (contradictory clauses, missing provisions, ambiguous language, asymmetric terms, circular references, pricing inconsistencies)
- **22 real contracts** from SEC EDGAR, GitHub, USDA, and other public sources

```bash
# Run against all test contracts
for f in tests-scenario/**/*.txt; do
  echo "=== $f ==="
  bin/contract-compiler analyze "$f" 2>/dev/null | tail -3
  echo
done
```

## License

MIT
