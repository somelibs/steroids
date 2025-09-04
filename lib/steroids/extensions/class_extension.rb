module Steroids
  module Extensions
    module ClassExtension
      # --------------------------------------------------------------------------------------------
      # Attributes
      # --------------------------------------------------------------------------------------------

      attr_reader :steroids_attributes_set

      def attribute(attribute_name, default: nil, type: nil, allow_nil: false)
        reference_steroids_attributes(attribute_name)
        expected_type = type.present? && type.constantize
        instance_variable_name = :"@#{attribute_name}"
        has_been_set = false

        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        # Define reader
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        # TODO: Alternatively to overriding freeze: method could return default if frozen, without
        # setting the actual instance variable.
        self.define_method(attribute_name) do
          unless instance_variable_get(instance_variable_name) || has_been_set || self.frozen?
            typed_and_nil = default.nil? && !!allow_nil
            default_value = expected_type.present? && !typed_and_nil ? default.typed!(expected_type) : default
            instance_variable_set(instance_variable_name, default_value)
          end
          instance_variable_get(instance_variable_name)
        end

        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        # Define writter
        # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        self.define_method(:"#{attribute_name}=") do |next_value|
          typed_and_nil = next_value.nil? && !!allow_nil
          value = expected_type.present? && !typed_and_nil ? next_value.typed!(expected_type) : next_value
          has_been_set = true
          instance_variable_set(instance_variable_name, value)
        end
      end

      private def reference_steroids_attributes(attribute_name)
        @steroids_attributes_set ||= Array.new
        @steroids_attributes_set << attribute_name
      end

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
        # condition = options.fetch(:if, nil)
        delegate_name = options.fetch(:to)
        method_names.each do |method_name|
          self.define_method(method_name) do |*arguments, **options, &block|
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
        class_name = name.to_s.camelize
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
