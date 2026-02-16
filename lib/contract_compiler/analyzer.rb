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
