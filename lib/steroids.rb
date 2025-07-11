# frozen_string_literal: true
require "steroids/railtie"
require "steroids/engine"

module Steroids
  loader.zeitwerk.setup
  loader.load_extensions!
end
