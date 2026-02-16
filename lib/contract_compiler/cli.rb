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
      # Strip the "analyze" subcommand if present
      remaining.shift if remaining.first == "analyze"
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
