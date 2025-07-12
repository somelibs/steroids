# frozen_string_literal: true
require "steroids/railtie"
require "steroids/engine"

module Steroids
  def self.loader
    @loader ||= Loader.new
  end

  loader.zeitwerk.setup
  loader.load_extensions!
end
