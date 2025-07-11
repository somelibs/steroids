module Steroids
  module Types
    class SerializableType < Steroids::Support::MagicClass
      include ActiveModel::Model
      include ActiveModel::Serialization

      def attributes
        self.class.attributes || []
      end

      class << self
        alias native_attr_accessor attr_accessor

        def attr_accessor(*attr)
          attributes(*attr)
        end

        def attributes(*attr)
          @attributes ||= []
          @attributes.concat(attr).uniq
          native_attr_accessor(*attr)
          @attributes
        end

        def attribute(attribute)
          @attributes ||= []
          @attributes << attribute unless @attributes.include?(attribute)
          native_attr_accessor(attribute)
          attr
        end
      end
    end
  end
end
