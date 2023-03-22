$:.push File.expand_path("lib", __dir__)

require "steroids/version"

Gem::Specification.new do | spec |
  spec.name        = 'steroids'
  spec.version     = Steroids::VERSION
  spec.date        = '2020-10-20'
  spec.summary     = "Steroids - Rails helpers"
  spec.description = "Steroids provides helper for Service-oriented, API based, Rails apps."
  spec.authors     = ["Paul Reboh"]
  spec.email       = 'dev@bernstein.io'
  spec.homepage    = 'https://github.com/bernstein-io/steroids'

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = ""
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files       = Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md"]

  spec.add_dependency "rails", ">= 6.0.2.1"
  spec.add_development_dependency "sqlite3"
end
