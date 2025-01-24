require "zeitwerk"
require "rails"
require "active_model_serializers"

module Steroids
  def self.root_path
    File.expand_path("..", __dir__)
  end

  module Loader
    def self.file_update_checker(&loader)
      root_path = Steroids.root_path
      file_matcher = Dir["#{root_path}/steroids/**/*.rb"]
      @file_update_checker ||= ActiveSupport::FileUpdateChecker.new(file_matcher, &loader)
    end

    def self.zeitwerk
      @loader ||= Zeitwerk::Loader.new.tap do |loader|
        root_path = Steroids.root_path
        loader.tag = "steroids"
        loader.inflector = Zeitwerk::GemInflector.new("#{root_path}/steroids.rb")
        loader.enable_reloading
        loader.push_dir(root_path)
        loader.ignore(
          "#{root_path}/steroids/railties.rb",
          "#{root_path}/steroids/version.rb"
        )
      end
    end

    zeitwerk.setup
  end
end
