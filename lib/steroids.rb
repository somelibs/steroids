# frozen_string_literal: true
require "steroids/railtie"
require "steroids/engine"

module Steroids
  def self.root_path
    Engine.root.to_s
  end

  def self.loader
    @loader ||= Loader.new
  end

  loader.zeitwerk.setup
  loader.load_extensions!
end
