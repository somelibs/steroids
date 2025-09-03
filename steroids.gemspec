# -*- encoding: utf-8 -*-
# frozen_string_literal: true

$:.push File.expand_path("lib", __dir__)

require "steroids/version"

Gem::Specification.new do | spec |
  spec.name        = "steroids"
  spec.version     = Steroids::VERSION
  spec.date        = "2025-09-01"
  spec.summary     = "Steroids - Rails helpers"
  spec.description = spec.summary
  spec.authors     = ["Paul Reboh"]
  spec.email       = "paul@reboh.net"
  spec.homepage    = "https://github.com/somelibs/steroids"
  spec.required_ruby_version = ">= 3.0.0"

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = ""
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files       = Dir["{app,config,misc,db,lib}/**/*", "Rakefile", "README.md"]

  spec.add_dependency "rainbow", ">= 3.1"
  spec.add_dependency "rails", ">= 7"
end
