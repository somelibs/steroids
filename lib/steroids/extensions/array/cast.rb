module Steroids
  module Extensions
    module Array
      module Cast
        class ElementNotFound < StandardError; end

        def cast(value)
          self.find { |item| item == value } or raise ElementNotFound.new("Cast: Element not found (#{value})")
        end
      end
    end
  end
end

Array.include(Steroids::Extensions::Array::Cast)
