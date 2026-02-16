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
      skip "No PDF fixture" unless File.exist?("spec/fixtures/sample.pdf")
      text = described_class.parse("spec/fixtures/sample.pdf")
      expect(text).to be_a(String)
      expect(text.length).to be > 0
    end
  end
end
