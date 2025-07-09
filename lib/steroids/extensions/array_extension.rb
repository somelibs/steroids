module Steroids
  module Extensions
    module ArrayExtension
      class ElementNotFound < StandardError; end

      def cast(value)
        self.find { |item| item == value } or raise ElementNotFound.new("Cast: Element not found (#{value})")
      end

      def find_map(&block)
        return enum_for(:find_map) unless block_given?

        each do |element|
          result = yield(element)

          return result if result
        end

        nil
      end
    end
  end
end

Array.include(Steroids::Extensions::ArrayExtension)
