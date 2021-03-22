# frozen-string-literal: true

require_relative 'lib/jiratk/version'

Gem::Specification.new do |spec|
  spec.name          = 'jiratk'
  spec.version       = JiraTk::VERSION
  spec.authors       = ['dave doolin']
  spec.email         = ['david.doolin@gmail.com']

  spec.summary       = 'Specialist API wrapper for managing Jira issues.'
  spec.description   = 'API wrapper for creating and acquiring Jira issues.'
  spec.homepage      = 'https://github.com/doolin/jiratk'
  spec.license       = 'BSD'
  spec.required_ruby_version = '>= 2.7.2'

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/doolin/jiratk'
  spec.metadata['changelog_uri'] = 'https://github.com/doolin/jiratk'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'aruba'
  spec.add_development_dependency 'cucumber'
end
