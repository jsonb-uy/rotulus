require_relative 'lib/rotulus/version'

Gem::Specification.new do |spec|
  spec.name          = "rotulus"
  spec.version       = Rotulus::VERSION
  spec.authors       = ['Uy Jayson B']
  spec.email         = ['uy.json.dev@gmail.com']

  spec.summary       = 'Cursor-based Rails/ActiveRecord pagination with multiple column sort and custom cursor token format support.'
  spec.description   = 'Cursor-based pagination for Rails/ActiveRecord apps with multiple column sort and custom cursor format support for a more stable and predictable pagination.'
  spec.homepage      = 'https://github.com/jsonb-uy/rotulus'
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jsonb-uy/rotulus"
  spec.metadata["changelog_uri"] = "https://github.com/jsonb-uy/rotulus/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/github/jsonb-uy/rotulus/main"
  spec.metadata["bug_tracker_uri"] = "https://github.com/jsonb-uy/rotulus/issues"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir['CHANGELOG.md', 'LICENSE', 'README.md', 'lib/**/*']
  spec.require_paths = ["lib"]

  spec.add_dependency 'activerecord', '>= 4.2', '< 7.1'
  spec.add_dependency 'activesupport', '>= 4.2', '< 7.1'
  spec.add_dependency 'oj'

  spec.bindir        = "bin"
  spec.executables   = []
end
