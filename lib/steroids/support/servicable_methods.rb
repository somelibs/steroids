module Steroids
  module Support
    module ServicableMethods
      extend ActiveSupport::Concern

      included do
        def noticable_binding
          Proc.new do |concern|
            if self.respond_to?(:noticable) && concern.respond_to?(:noticable)
              self.noticable.merge(concern.noticable)
            end
          end
        end

        def service_context_for(options)
          respond_to?(:context) ? context.merge(options).symbolize_keys : options
        end
      end

      class_methods do
        def service(service_name, class_name:, **class_options)
          define_method service_name do | *args, **options, &block |
            service_options = service_context_for(options)
            service_block = block.present? ? block : noticable_binding
            service_class = Object.const_get(class_name)
            instance = service_class.new(*args, **service_options)
            # Propagate parent's async preference to sub-services unless explicitly overridden
            instance.call(**{
              **class_options,
              **options,
              async: !options.key?(:async) && @steroids_async == true
            }, &service_block)
          end
        end
      end
    end
  end
end
