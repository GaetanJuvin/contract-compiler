require "optparse"
require "colorize"

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
      verbose = options[:verbose]
      start_time = Time.now

      # Header
      $stderr.puts ""
      $stderr.puts "  CONTRACT COMPILER".bold.cyan + "  v1.0".light_black
      $stderr.puts "  #{"=" * 50}".light_black
      $stderr.puts ""

      # Step 1: Parse
      step_start = Time.now
      $stderr.print "  #{"[1/6]".bold.blue} #{"Parsing file".white}  #{options[:file].light_black} "
      text = Parser.parse(options[:file])
      elapsed = ((Time.now - step_start) * 1000).round
      $stderr.puts "#{"✓".green} #{format_ms(elapsed)}"
      if verbose
        $stderr.puts "        #{text.length} characters, #{text.lines.count} lines".light_black
      end

      # Step 2: Clause extraction
      step_start = Time.now
      $stderr.print "  #{"[2/6]".bold.blue} #{"Extracting clauses".white} "
      clauses = ClauseExtractor.extract(text)
      elapsed = ((Time.now - step_start) * 1000).round
      $stderr.puts "#{"✓".green} #{format_ms(elapsed)}"
      if verbose
        $stderr.puts "        #{clauses.length} clauses found".light_black
        clauses.each do |c|
          indent = "  " * c.level
          line_ref = c.line ? ":#{c.line}".light_black : ""
          $stderr.puts "        #{indent}#{"├─".light_black} #{c.id.yellow}#{line_ref} #{c.title.truncate(60).white}"
        end
      end

      # Step 3: Semantic extraction
      step_start = Time.now
      $stderr.print "  #{"[3/6]".bold.blue} #{"Extracting semantics".white} "
      semantic_result = SemanticExtractor.extract(clauses)
      parties = SemanticExtractor.extract_parties(text)
      elapsed = ((Time.now - step_start) * 1000).round
      $stderr.puts "#{"✓".green} #{format_ms(elapsed)}"
      if verbose
        obligations = semantic_result[:nodes].count { |n| n.is_a?(DAG::ObligationNode) }
        rights = semantic_result[:nodes].count { |n| n.is_a?(DAG::RightNode) }
        conditions = semantic_result[:nodes].count { |n| n.is_a?(DAG::ConditionNode) }
        $stderr.puts "        #{"Obligations:".light_white} #{obligations.to_s.yellow}  #{"Rights:".light_white} #{rights.to_s.cyan}  #{"Conditions:".light_white} #{conditions.to_s.magenta}"
        $stderr.puts "        #{"Parties:".light_white} #{parties.map(&:to_s).join(", ").light_black}"
      end

      # Step 4: DAG construction
      step_start = Time.now
      $stderr.print "  #{"[4/6]".bold.blue} #{"Building DAG".white} "
      graph = build_graph(clauses, semantic_result)
      elapsed = ((Time.now - step_start) * 1000).round
      $stderr.puts "#{"✓".green} #{format_ms(elapsed)}"
      if verbose
        clause_nodes = graph.nodes.count { |n| n.is_a?(DAG::ClauseNode) }
        semantic_nodes = graph.nodes.length - clause_nodes
        $stderr.puts "        #{"Nodes:".light_white} #{graph.nodes.length.to_s.yellow} (#{clause_nodes} clause + #{semantic_nodes} semantic)".light_black
        $stderr.puts "        #{"Edges:".light_white} #{graph.edges.length.to_s.yellow}".light_black
        edge_types = graph.edges.group_by(&:type).transform_values(&:count)
        edge_types.each do |type, count|
          $stderr.puts "          #{type.to_s.cyan}: #{count}"
        end
      end

      # Step 5: Symbolic reasoning
      step_start = Time.now
      $stderr.print "  #{"[5/6]".bold.blue} #{"Running symbolic reasoner".white} "
      symbolic_anomalies = Reasoner.analyze(graph)
      elapsed = ((Time.now - step_start) * 1000).round
      $stderr.puts "#{"✓".green} #{format_ms(elapsed)}"
      if verbose
        if symbolic_anomalies.empty?
          $stderr.puts "        No symbolic anomalies detected".light_black
        else
          symbolic_anomalies.each do |a|
            severity_color = severity_to_color(a[:severity])
            sev = a[:severity].to_s.upcase
            line_refs = (a[:lines] || []).map { |l| "L#{l}" }.join(",")
            line_str = line_refs.empty? ? "" : " #{line_refs.cyan}"
            $stderr.puts "        #{"⚠".send(severity_color)} #{sev.send(severity_color)}#{line_str} #{a[:type].to_s.light_black} #{a[:description].truncate(80).white}"
          end
        end
      end

      # Step 6: OpenAI analysis
      step_start = Time.now
      $stderr.print "  #{"[6/6]".bold.blue} #{"Calling OpenAI analyzer".white} #{"(gpt-5.2)".light_black} "
      ai_anomalies = Analyzer.analyze(
        graph_hash: graph.to_hash,
        original_text: text,
        symbolic_anomalies: symbolic_anomalies
      )
      elapsed = ((Time.now - step_start) * 1000).round
      $stderr.puts "#{"✓".green} #{format_ms(elapsed)}"
      if verbose
        $stderr.puts "        #{ai_anomalies.length} AI anomalies detected".light_black
      end

      # Summary
      total_elapsed = ((Time.now - start_time) * 1000).round
      all_anomalies = symbolic_anomalies.map { |a| a.merge(source: :symbolic) } + ai_anomalies
      $stderr.puts ""
      $stderr.puts "  #{"Done!".bold.green} #{all_anomalies.length} anomalies found in #{format_ms(total_elapsed)}"
      $stderr.puts ""

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

    def self.format_ms(ms)
      if ms < 1000
        "#{ms}ms".light_black
      else
        "#{"%.1f" % (ms / 1000.0)}s".light_black
      end
    end

    private_class_method :format_ms

    def self.severity_to_color(severity)
      case severity.to_s.downcase
      when "critical" then :red
      when "high" then :light_red
      when "medium" then :yellow
      when "low" then :light_black
      else :white
      end
    end

    private_class_method :severity_to_color
  end
end

class String
  def truncate(max)
    length > max ? self[0...max] + "..." : self
  end unless method_defined?(:truncate)
end
