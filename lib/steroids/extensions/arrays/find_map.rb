module Steroids
  module Extensions
    module Arrays
      module FindMap
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
end

Array.include(Steroids::Extensions::Arrays::FindMap)
