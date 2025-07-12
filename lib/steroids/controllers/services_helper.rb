module Steroids
  module Controllers
    module ServicesHelper
      extend ActiveSupport::Concern

      class_methods do
        attr_accessor :services

        def service(service_name, class_name:, **options, &block)
          define_method service_name do | *args, **options, &block |
            merged_options = context.merge(options).symbolize_keys
            Object.const_get(class_name).new(
              *args,
              **merged_options
            ).call(**options, &block)
          end
        end
      end
    end
  end
end
