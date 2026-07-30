# frozen_string_literal: true

require_relative 'lib/mcp/version'

Gem::Specification.new do |spec|
  spec.name          = 'legacy-mcp'
  spec.version       = Mcp::VERSION
  spec.authors       = ['Christian García']
  spec.email         = ['']

  spec.summary       = 'MCP (Model Context Protocol) server framework for legacy Ruby/Rails apps (Ruby >= 2.6) that cannot run the official mcp gem.'
  spec.description   = <<~DESC
    legacy-mcp is a lightweight, pure-Ruby implementation of the Model Context Protocol
    (MCP) server framework, designed for older Ruby and Rails applications (Ruby >= 2.6)
    that cannot use the official `mcp` gem due to version constraints.

    It provides a JSON-RPC 2.0 server that handles the MCP protocol (initialize, ping,
    resources/list, resources/read, tools/list, tools/call) and base classes for defining
    resources and tools. No Rails dependency — works with any Rack-compatible framework.

    WORK IN PROGRESS — not yet published to RubyGems.org. Protocol version: 2024-11-05.
  DESC
  spec.homepage      = 'https://github.com/chr/legacy-mcp'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.6'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/chr/legacy-mcp'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    Dir['{lib,spec}/**/*.rb', 'README.md', 'LICENSE', '*.gemspec']
  end
  spec.bindir        = 'exe'
  spec.executables   = []
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rake', '~> 13.0'
end
