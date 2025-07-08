module Steroids
  module Extensions
    module Arrays
      module Cast
        class ElementNotFound < StandardError; end

        def cast(value)
          self.find { |item| item == value } or raise ElementNotFound.new("Cast: Element not found (#{value})")
        end
      end
    end
  end
end

Array.include(Steroids::Extensions::Arrays::Cast)
