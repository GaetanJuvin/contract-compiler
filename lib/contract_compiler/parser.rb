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
