Gem::Specification.new do | spec |
  spec.name        = 'steroids'
  spec.version     = Steroids::VERSION
  spec.date        = '2020-10-20'
  spec.summary     = "Steroids - Rails helpers"
  spec.description = "Steroids provides helper for Service-oriented, API based, Rails apps."
  spec.authors     = ["Paul Reboh"]
  spec.email       = 'dev@bernstein.io'
  spec.homepage    = 'https://github.com/bernstein-io/steroids'
  spec.files       = Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md"]
  spec.add_dependency "rails", "~> 6.0.2", ">= 6.0.2.1"
  spec.add_development_dependency "sqlite3"

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = false
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end
end
