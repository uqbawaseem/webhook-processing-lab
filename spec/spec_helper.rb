RSpec.configure do |config|
  config.order = :random
  Kernel.srand config.seed
  config.expect_with(:rspec) { |expectations| expectations.include_chain_clauses_in_custom_matcher_descriptions = true }
end
