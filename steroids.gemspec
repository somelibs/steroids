$:.push File.expand_path("lib", __dir__)

require "steroids/version"

Gem::Specification.new do | spec |
  spec.name        = 'steroids'
  spec.version     = Steroids::VERSION
  spec.date        = '2021-03-04'
  spec.summary     = "Steroids - Rails helpers"
  spec.description = "Steroids provides helper for Service-oriented, API based, Rails apps."
  spec.authors     = ["Paul Reboh"]
  spec.email       = 'paul@reboh.net'
  spec.homepage    = 'https://github.com/somelibs/steroids'
  spec.required_ruby_version = ">= 2.7.0"

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = ""
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files       = Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md"]

  spec.add_dependency "rainbow", ">= 3.1"
  spec.add_dependency "rails", ">= 6"
  spec.add_development_dependency "sqlite3"
end
