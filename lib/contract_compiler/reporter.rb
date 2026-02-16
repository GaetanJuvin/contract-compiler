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
          location = format_location(metadata[:source_file], anomaly)
          lines << "  #{location} [#{prefix}#{i + 1}] #{anomaly[:description]}"
          lines << "       Recommendation: #{anomaly[:recommendation]}" if anomaly[:recommendation]
        end

        lines << ""
      end

      critical_high = counters[:critical] + counters[:high]
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

    def self.format_location(source_file, anomaly)
      lines = anomaly[:lines] || []
      if lines.any?
        lines.map { |l| "#{source_file}:#{l}:" }.join(" ")
      else
        "#{source_file}:"
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

    private_class_method :group_by_severity, :severity_prefix, :count_by_severity, :stringify_keys, :format_location
  end
end
