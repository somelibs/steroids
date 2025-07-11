# frozen_string_literal: true
module Steroids
  class Engine < ::Rails::Engine
    config.steroids = Steroids
  end
end
