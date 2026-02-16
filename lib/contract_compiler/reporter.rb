require "json"
require "colorize"

module ContractCompiler
  class Reporter
    SEVERITY_ORDER = %i[critical high medium low].freeze

    SEVERITY_COLORS = {
      critical: { label: :red, icon: "\u2718", bg: :light_red },       # ✘
      high:     { label: :light_red, icon: "\u26A0", bg: nil },        # ⚠
      medium:   { label: :yellow, icon: "\u25CF", bg: nil },           # ●
      low:      { label: :light_black, icon: "\u25CB", bg: nil },      # ○
    }.freeze

    def self.format_text(anomalies:, metadata:, color: $stdout.tty?)
      lines = []

      if color
        lines << ""
        lines << "  #{"Contract Analysis Report".bold.white}"
        lines << "  #{"=" * 56}".light_black
        lines << "  Source: #{metadata[:source_file].cyan} (#{metadata[:clause_count].to_s.yellow} clauses, #{metadata[:party_count].to_s.yellow} parties)"
      else
        lines << "Contract Analysis Report"
        lines << "=" * 60
        lines << "Source: #{metadata[:source_file]} (#{metadata[:clause_count]} clauses, #{metadata[:party_count]} parties)"
      end
      lines << ""

      grouped = group_by_severity(anomalies)
      counters = { critical: 0, high: 0, medium: 0, low: 0 }

      SEVERITY_ORDER.each do |severity|
        items = grouped[severity] || []
        next if items.empty?

        counters[severity] = items.length
        style = SEVERITY_COLORS[severity]

        if color
          header = "#{style[:icon]} #{severity.to_s.upcase} (#{items.length})"
          lines << "  #{header.send(style[:label]).bold}"
        else
          lines << "#{severity.to_s.upcase} (#{items.length})"
        end

        items.each_with_index do |anomaly, i|
          prefix = severity_prefix(severity)
          tag = "[#{prefix}#{i + 1}]"

          if color
            location = format_location_color(metadata[:source_file], anomaly)
            lines << "    #{location} #{tag.send(style[:label]).bold} #{anomaly[:description].white}"
            if anomaly[:recommendation]
              lines << "    #{"   Recommendation:".green} #{anomaly[:recommendation].light_black}"
            end
          else
            location = format_location(metadata[:source_file], anomaly)
            lines << "  #{location} #{tag} #{anomaly[:description]}"
            if anomaly[:recommendation]
              lines << "       Recommendation: #{anomaly[:recommendation]}"
            end
          end
        end

        lines << ""
      end

      critical_high = counters[:critical] + counters[:high]

      if color
        parts = []
        parts << "#{counters[:critical]}".red.bold + " critical".red if counters[:critical] > 0
        parts << "#{counters[:high]}".light_red.bold + " high".light_red if counters[:high] > 0
        parts << "#{counters[:medium]}".yellow.bold + " medium".yellow if counters[:medium] > 0
        parts << "#{counters[:low]}".light_black + " low".light_black if counters[:low] > 0
        total = anomalies.length
        lines << "  #{"Summary:".bold} #{total} anomalies — #{parts.join(", ")}"
        lines << ""
      else
        lines << "Summary: #{critical_high} critical/high, #{counters[:medium]} medium, #{counters[:low]} low anomalies found."
      end

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

    def self.format_location(source_file, anomaly)
      line_nums = anomaly[:lines] || []
      if line_nums.any?
        line_nums.map { |l| "#{source_file}:#{l}:" }.join(" ")
      else
        "#{source_file}:"
      end
    end

    def self.format_location_color(source_file, anomaly)
      line_nums = anomaly[:lines] || []
      if line_nums.any?
        line_nums.map { |l| "#{source_file}:#{l}:".cyan }.join(" ")
      else
        "#{source_file}:".light_black
      end
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

    private_class_method :group_by_severity, :severity_prefix, :count_by_severity,
                         :stringify_keys, :format_location, :format_location_color
  end
end
