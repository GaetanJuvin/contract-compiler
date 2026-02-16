# lib/contract_compiler.rb
module ContractCompiler
end

require_relative "contract_compiler/dag/node"
require_relative "contract_compiler/dag/edge"
require_relative "contract_compiler/dag/graph"
require_relative "contract_compiler/parser"
require_relative "contract_compiler/clause_extractor"
require_relative "contract_compiler/semantic_extractor"
require_relative "contract_compiler/reasoner"
require_relative "contract_compiler/analyzer"
require_relative "contract_compiler/reporter"
require_relative "contract_compiler/cli"
