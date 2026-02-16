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

    it "strips the analyze subcommand" do
      options = described_class.parse_options(["analyze", "--json", "contract.txt"])
      expect(options[:file]).to eq("contract.txt")
      expect(options[:json]).to be true
    end
  end
end
