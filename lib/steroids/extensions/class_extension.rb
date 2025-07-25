module Steroids
  module Extensions
    module ClassExtension
      def delegate_alias(alias_name, to:, method:)
        define_method(alias_name) do |*arguments, **options, &block|
          delegate = send(to)
          delegate.send_apply(method, *arguments, **options, &block)
        end
      end

      def delegate_proxy(delegate_method_name, **options)
        respond_to_hander = options.fetch(:if)
        return unless self.instance_methods.include?(delegate_method_name) && respond_to_hander.present?

        define_method(:method_missing) do |missing_method_name, *args, **options, &block|
          if self.send(respond_to_hander, missing_method_name)
            self.send(delegate_method_name, missing_method_name)
          else
            super(missing_method_name, *args)
          end
        end
      end
    end
  end
end

Class.include(Steroids::Extensions::ClassExtension)
