module Steroids
  module Controllers
    module SerializersHelper
      extend ActiveSupport::Concern

      class_methods do
        attr_accessor :serializer

        def default_serializer(serializer)
          @serializer = serializer
        end
      end
    end
  end
end
