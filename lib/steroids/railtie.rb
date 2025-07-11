# frozen_string_literal: true
require "zeitwerk"
require "rails"
require "active_model_serializers"

module Steroids
  # ------------------------------------------------------------------------------------------------
  # Custom loader (Zeitwerk)
  # ------------------------------------------------------------------------------------------------
  class Loader
    def load_extensions!
      core_extensions = File.expand_path("#{gem_path}/steroids/extensions/**/**/*.rb", __dir__)
      extensions_dir = Dir.glob(core_extensions)
      Dir.glob(extensions_dir).sort.each do |path|
        load path
      end
    end

    def file_update_checker(&loader)
      watch_list = Dir["#{gem_path}/**/*.rb"]
      @file_update_checker ||= ActiveSupport::FileUpdateChecker.new(watch_list, &loader)
    end

    def zeitwerk
      @loader ||= Zeitwerk::Loader.new.tap do |loader|
        loader.tag = "steroids"
        loader.enable_reloading
        loader.push_dir(gem_path)
        loader.inflector = Zeitwerk::GemInflector.new("#{gem_path}/steroids.rb")
      end
    end

    private

    def gem_path
      @gem_path ||= File.expand_path("..", __dir__)
    end
  end

  # ------------------------------------------------------------------------------------------------
  # Rails hooks (Railtie)
  # ------------------------------------------------------------------------------------------------
  class Railtie < ::Rails::Railtie
    config.to_prepare do
      loader = Steroids.loader
      if loader.file_update_checker.updated?
        loader.file_update_checker.execute
        loader.zeitwerk.reload
      end
    end

    initializer "steroids.add_reloader" do |app|
      loader = Steroids.loader
      app.reloaders << loader.file_update_checker do
        loader.zeitwerk.reload
        loader.load_extensions!
      end
    end
  end

  # ------------------------------------------------------------------------------------------------
  # Initialize loader
  # ------------------------------------------------------------------------------------------------
  def self.loader
    @loader ||= Loader.new
  end
end
