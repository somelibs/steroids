module Steroids
  module Extensions
    module ClassExtension
      # --------------------------------------------------------------------------------------------
      # Methods
      # --------------------------------------------------------------------------------------------

      def runtime_methods(include_modules = true)
        methods = if include_modules
          self.methods(true)
        else
          methods = []
          klass = self.class
          while klass
            methods += klass.methods
            klass = klass.superclass
          end
          methods
        end

        methods - Object.methods
      end

      def runtime_instance_methods(include_modules = true)
        methods = if include_modules
          self.instance_methods(true)
        else
          methods = []
          klass = self.class
          while klass
            methods += klass.methods
            klass = klass.superclass
          end
          methods
        end

        methods - Object.instance_methods
      end

      # --------------------------------------------------------------------------------------------
      # Delegate, proxy and so on
      # --------------------------------------------------------------------------------------------

      def delegate_alias(alias_name, to:, method:)
        define_method(alias_name) do |*arguments, **options, &block|
          delegate = send(to)
          delegate.send_apply(method, *arguments, **options, &block)
        end
      end

      def forward_methods_to(method_name, **options)
        respond_to_hander = options.fetch(:if)
        return unless self.instance_methods.include?(method_name) && respond_to_hander.present?

        define_method(:method_missing) do |missing_method_name, *arguments, **options, &block|
          if self.send_apply(respond_to_hander, missing_method_name)
            self.send_apply(method_name, missing_method_name)
          else
            super(missing_method_name, *arguments, **options, &block)
          end
        end
      end

      def try_delegate(*method_names, **options)
        condition = options.fetch(:if, nil)
        delegate_name = options.fetch(:to)
        method_names.each do |method_name|
          self.define_method(method_name) do |*arguments, **options, &block|
            should_delegate = condition.present? ? !!self.send(condition) : true
            delegate_object = self.try(delegate_name) rescue false
            if delegate_object.present? && delegate_object.try_method(method_name)
              delegate_object.send_apply(method_name, *arguments, **options, &block)
            else
              super(*arguments, **options, &block)
            end
          end
        end
      end

      # --------------------------------------------------------------------------------------------
      # Naming
      # --------------------------------------------------------------------------------------------

      def own_klass_name
        self.name.split('::').last
      end

      # --------------------------------------------------------------------------------------------
      # Anonymous class building
      # --------------------------------------------------------------------------------------------

      def proxy(instance, &block)
        name = "#{instance.class.name}Proxy"
        Class.build_anonymous(name) do
          include Module.new(&block)

          define_method(:klass) do
            instance.class
          end

          define_method(:method_missing) do |missing_method_name, *arguments, **options, &block|
            if instance.respond_to?(missing_method_name, true)
              instance.send_apply(missing_method_name, *arguments, **options, &block)
            else
              super(missing_method_name, *arguments, **options, &block)
            end
          end

          define_method(:respond_to_missing?) do |missing_method_name, *arguments, **options, &block|
            !!instance.respond_to?(missing_method_name, true)
          end
        end.new
      end

      def build_anonymous(name, **options, &block)
        parent_class = options.fetch(:inherit, nil) || Class.new
        class_name = name.camelize
        self.new(parent_class) do
          include Module.new(&block)

          define_singleton_method(:name) do
            class_name
          end

          define_singleton_method(:inspect) do
            super().gsub("#<Class:", "#<Anonymous:#{class_name}:")
          end

          define_singleton_method(:to_s) do
            self.inspect
          end

          define_singleton_method(:anonymous?) do
            true
          end
        end
      end
    end
  end
end

Class.include(Steroids::Extensions::ClassExtension)
