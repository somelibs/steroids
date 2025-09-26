module Steroids
  module Extensions
    module ArrayExtension
      class ElementNotFound < StandardError; end

      def cast(value, indifferent_access = false)
        self.find do |item|
          indifferent_access ? (item.to_sym == value&.to_sym) : (item == value)
        end or raise ElementNotFound.new("Cast: Element not found (#{value})")
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
