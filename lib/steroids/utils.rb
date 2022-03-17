module Steroids
  module Utils
    class CastError < Steroids::Errors::GenericError; end

    def self.cast(value = nil, options = [])
      return nil unless  options.include?(value)
      value
    end

    def self.cast!(value, options)
      raise CastError.new(message: "Failed to cast #{value.to_s}") unless self.cast(value) == value
    end
  end
end
