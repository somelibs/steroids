require "steroids/loader"

module Steroids
  class Railtie < ::Rails::Railtie
    config.to_prepare do
      Steroids::Loader.zeitwerk.reload
    end
  end
end
