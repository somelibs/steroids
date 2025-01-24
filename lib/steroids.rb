require "zeitwerk"
require "steroids/loader"

module Steroids
  class Railtie < ::Rails::Railtie
    config.to_prepare do
      Steroids::Loader.zeitwerk.reload
    end

    initializer "steroids.add_reloader" do |app|
      app.reloaders << Steroids::Loader.file_update_checker do
        Steroids::Loader.zeitwerk.reload
      end
    end
  end
end
