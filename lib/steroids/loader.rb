require "zeitwerk"
require "rails"
require "active_model_serializers"

module Steroids
  def self.gem_path
    File.expand_path("..", __dir__)
  end

  module Loader
    def self.load_extensions!
      gem_path = Steroids.gem_path
      extensions_dir = Dir.glob(File.expand_path("#{gem_path}/steroids/extensions/**/**/*.rb", __dir__))
      Dir.glob(extensions_dir).sort.each do |path|
        load path
      end
    end

    def self.file_update_checker(&loader)
      gem_path = Steroids.gem_path
      watch_list = Dir["#{gem_path}/**/*.rb"]
      @file_update_checker ||= ActiveSupport::FileUpdateChecker.new(watch_list, &loader)
    end

    def self.zeitwerk
      @loader ||= Zeitwerk::Loader.new.tap do |loader|
        gem_path = Steroids.gem_path
        loader.tag = "steroids"
        loader.enable_reloading
        loader.push_dir(gem_path)
        loader.inflector = Zeitwerk::GemInflector.new("#{gem_path}/steroids.rb")
      end
    end

    zeitwerk.setup
  end
end
