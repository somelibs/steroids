module Steroids
  module Extensions
    module HashExtension
      def fetch_any(*values)
        matching_key = self.keys.find do |key|
          !!values.include?(key)
        end
        self[matching_key]
      end
    end
  end
end

Hash.include(Steroids::Extensions::HashExtension)
