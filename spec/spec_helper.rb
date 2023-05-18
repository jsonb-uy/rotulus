ENV['RAILS_ENV'] ||= 'test'

require 'rotulus'
require 'rotulus/db/mysql'
require 'rotulus/db/postgresql'
require 'rotulus/db/sqlite'
require 'rspec'

Dir[File.expand_path('support/*.rb', __dir__)].sort.each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.before do
    Rotulus.configuration.secret = 'some-secret'
  end

  config.after do
    User.delete_all
  end

  config.before(:example, postgresql: true) do
    allow(Rotulus).to receive(:db) { Rotulus::DB::PostgreSQL.new }
  end

  config.before(:example, mysql: true) do
    allow(Rotulus).to receive(:db) { Rotulus::DB::MySQL.new }
  end

  config.before(:example, sqlite: true) do
    allow(Rotulus).to receive(:db) { Rotulus::DB::SQLite.new }
  end

  config.include(CustomMatchers)

  config.example_status_persistence_file_path = 'tmp/failures.txt'
end
