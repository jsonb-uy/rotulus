source 'https://rubygems.org'
gemspec

rails_version = ENV['RAILS_VERSION'] || '7-0-stable'

gem 'rake'
gem 'rspec'

if ENV.fetch('COVERAGE', nil) == 'true'
  gem 'simplecov'
  gem 'simplecov-cobertura'
end

case rails_version
when '4-2-stable'
  # Ruby 2.2 or newer.
  gem 'pg', '~> 0.15'
  gem 'sqlite3', '~> 1.3.6'
  gem 'mysql2', '~> 0.4.4'
when '5-0-stable', '5-1-stable', '5-2-stable'
  # Ruby 2.2.2 or newer.
  gem 'pg', '~> 0.18'
  gem 'sqlite3', '~> 1.3.6'
  gem 'mysql2', '~> 0.4.4'
when '6-0-stable'
  # Ruby 2.5.0 or newer.
  gem 'pg', '~> 0.18'
  gem 'sqlite3', '~> 1.4'
  gem 'mysql2', '>= 0.4.4'
when '6-1-stable'
  # Ruby 2.5.0 or newer.
  gem 'pg', '~> 1.1'
  gem 'sqlite3', '~> 1.4'
  gem 'mysql2', '~> 0.5'
when '7-0-stable'
  # Ruby 2.7.0 or newer.
  gem 'pg', '~> 1.1'
  gem 'sqlite3', '~> 1.4'
  gem 'mysql2', '~> 0.5'
else
  gem 'pg'
  gem 'sqlite3'
  gem 'mysql2'
end

gem 'rails', git: 'https://github.com/rails/rails', branch: rails_version
