require "zeitwerk"
require "steroids/loader"

module Steroids
  Steroids::Loader.load_extensions!

  class Railtie < ::Rails::Railtie
    config.to_prepare do
      if Steroids::Loader.file_update_checker.updated?
        Steroids::Loader.file_update_checker.execute
        Steroids::Loader.zeitwerk.reload
      end
    end

    initializer "steroids.add_reloader" do |app|
      app.reloaders << Steroids::Loader.file_update_checker do
        Steroids::Loader.zeitwerk.reload
        Steroids::Loader.load_extensions!
      end
    end
  end
end
