# frozen_string_literal: true

require_relative "lib/alpha_api/version"

Gem::Specification.new do |spec|
  spec.name          = "alpha_api"
  spec.version       = AlphaApi::VERSION
  spec.authors       = ["Alba Hoo"]
  spec.email         = ["alba@tenty.co"]

  spec.summary       = "RESTfulise model with jsonapi"
  spec.description   = "Expose models with restful api"
  spec.homepage      = "https://github.com/AlbaHoo/AlphaApi"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/AlbaHoo/AlphaApi"
  spec.metadata["changelog_uri"] = "https://github.com/AlbaHoo/AlphaApi"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency 'activesupport'
  spec.add_dependency 'actionpack'
  spec.add_dependency 'cancancan'
  spec.add_dependency 'fast_jsonapi'
  # For actual pagination
  spec.add_dependency 'kaminari'
  # For rest pagination, using kaminari automatically
  spec.add_dependency 'api-pagination'

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
