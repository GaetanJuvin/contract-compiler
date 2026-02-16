# Contract Compiler Design

## Overview

A Ruby CLI tool that parses contracts (text/PDF), builds a two-layer DAG via symbolic reasoning, then uses OpenAI to detect anomalies. Targets all contract types: legal, financial/procurement, and general structured documents.

## Architecture

Pipeline architecture:

```
Input (txt/pdf)
    -> Parser (extract raw text)
    -> Clause Extractor (split into structural sections)
    -> Semantic Extractor (obligations, rights, conditions, parties)
    -> DAG Builder (two-layer graph: clause layer + semantic layer)
    -> Symbolic Reasoner (rule-based anomaly detection on the DAG)
    -> OpenAI Analyzer (feed DAG + original text to GPT for deeper anomalies)
    -> Reporter (formatted text or JSON to stdout)
```

## Project Structure

```
contract-compiler/
├── Gemfile
├── bin/
│   └── contract-compiler        # CLI entrypoint
├── lib/
│   └── contract_compiler/
│       ├── cli.rb               # Argument parsing
│       ├── parser.rb            # Text/PDF extraction
│       ├── clause_extractor.rb  # Structural decomposition
│       ├── semantic_extractor.rb # Obligations/rights/conditions
│       ├── dag/
│       │   ├── node.rb          # Node types (clause, obligation, right, condition)
│       │   ├── edge.rb          # Edge types (references, depends_on, conflicts)
│       │   └── graph.rb         # DAG construction + validation
│       ├── reasoner.rb          # Symbolic rule engine
│       ├── analyzer.rb          # OpenAI integration
│       └── reporter.rb          # Output formatting
└── spec/                        # Tests
```

## Dependencies

- `light-openai-lib` — OpenAI Chat Completions API wrapper
- `pdf-reader` — PDF text extraction (pure Ruby, no system deps)
- `optparse` — CLI argument parsing (stdlib)

## Parser & Extractors

### Parser

Detects file type by extension. For `.pdf`, uses `pdf-reader` to extract text page by page. For `.txt`, reads the file directly. Returns a plain text string.

### Clause Extractor

Splits raw text into structural clauses using pattern matching:
- Numbered sections (`1.`, `1.1`, `Article I`)
- Headed sections (all-caps lines, bold markers)
- Falls back to paragraph splitting if no structure is detected

Each clause becomes a `ClauseNode` with: `id`, `title`, `body`, `level` (nesting depth), `parent_id`.

### Semantic Extractor

Scans each clause body with regex + keyword patterns to extract:
- **Obligations** — "shall", "must", "agrees to", "is required to"
- **Rights** — "may", "is entitled to", "has the right to"
- **Conditions** — "if", "provided that", "subject to", "upon"
- **Parties** — extracted from preamble or inferred from context
- **Temporal references** — dates, durations, "within X days", "before", "after"

Each extracted element becomes a semantic node linked back to its source clause via a `derived_from` edge. This layer is intentionally rule-based (no AI) so the DAG structure is deterministic and inspectable.

## DAG Structure

Two-layer directed acyclic graph.

### Node Types
- `ClauseNode` — structural layer (id, title, body, level, parent_id)
- `ObligationNode` — party, action, target party, temporal constraint
- `RightNode` — party, entitlement, scope
- `ConditionNode` — trigger, consequence, referenced clauses

### Edge Types
- `references` — clause A mentions clause B
- `derived_from` — semantic node extracted from a clause
- `depends_on` — obligation/right is contingent on a condition
- `conflicts_with` — detected by the reasoner (potential contradiction)

### Graph API
- `add_node`, `add_edge`
- `topological_sort`, `cycle_detect`
- `find_paths(from, to)`
- `to_hash` — serializable for OpenAI

## Symbolic Reasoner

Applies deterministic rules to the DAG and produces `Anomaly` structs (type, severity, description, involved nodes).

### Rules
- **Circular dependencies** — condition A requires B which requires A
- **Contradictory obligations** — same party must and must not do the same thing
- **Unmatched references** — clause references a section that doesn't exist
- **Orphaned obligations** — obligation with no party or no condition path
- **Temporal impossibilities** — "within 5 days" but depends on something due in 30 days
- **Missing reciprocity** — one party has obligations with no corresponding rights
- **Dangling conditions** — condition defined but never triggers anything

Each rule is a method, making it easy to add new rules later.

## OpenAI Analyzer

Uses `light-openai-lib` to call OpenAI with:
- The serialized DAG (`graph.to_hash`) as JSON
- The original contract text
- The symbolic reasoner's findings (to avoid duplication)

Asks OpenAI to find anomalies the symbolic reasoner cannot catch:
- **Ambiguous language** — vague terms without definition ("reasonable", "timely", "best efforts")
- **Industry-standard gaps** — missing clauses typical for the contract type
- **Asymmetric terms** — unfairly one-sided provisions
- **Inconsistent definitions** — same term used differently across clauses
- **Hidden implications** — clause combinations that create unintended consequences

Response requested in JSON mode for reliable parsing. Each AI-detected anomaly gets: type, severity (low/medium/high/critical), description, involved clauses, and recommendation.

## Reporter

Merges symbolic + AI anomalies into a unified report.

### Formatted Text (default)

```
Contract Analysis Report
========================
Source: contract.pdf (24 clauses, 3 parties)

CRITICAL (1)
  [C1] Contradictory obligations in S4.2 and S7.1 -- ...

HIGH (3)
  [H1] Missing indemnification clause -- ...
  ...

Summary: 4 critical/high, 6 medium, 2 low anomalies found.
```

### JSON (`--json` flag)

Full structured output with DAG, all anomalies, and metadata.

## CLI Interface

```
Usage: contract-compiler analyze [options] FILE
    --json       Output as JSON
    --verbose    Show DAG structure and extraction details
    --help       Show help
```
