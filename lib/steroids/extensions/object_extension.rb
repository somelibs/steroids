module Steroids
  module Extensions
    module ObjectExtension
      def ifnil(default)
        itself == nil ? default : itself
      end

      def instance_apply(*arguments, **options, &block)
        expected_argument_count = block.arguments.count
        expected_options_count = block.options.count
        applied_arguments = arguments.first(expected_argument_count) rescue []
        applied_options = options.select {|key| block.options.include?(key) } rescue {}
        self.instance_exec(*applied_arguments, **applied_options, &block)
      end

      def send_apply(method_name, *arguments, **options, &block)
        return unless respond_to?(method_name, true)

        method = method(method_name)
        expected_argument_count = method.arguments.count
        expected_options_count = method.options.count
        applied_arguments = arguments.first(expected_argument_count) rescue []
        applied_options = options.select {|key| method.options.include?(key) } rescue {}
        self.send(method_name, *applied_arguments, **applied_options, &block)
      end

      def send_apply!(method_name, *arguments, **options, &block)
        return NoMethodError.new("Send apply", method_name) unless self.respond_to?(method_name, true)

        send_apply(method_name, *arguments, **options, &block)
      end

      def try_method(method_name)
        if self.respond_to?(method_name, true)
          self.method(method_name)
        end
      end

      def typed!(expected_type)
        return itself if instance_of?(expected_type) || itself == nil

        message = "Expected #{self.inspect} to be an instance of #{expected_type.inspect}"
        TypeError.new(message).tap do |exception|
          exception.set_backtrace(caller)
          raise exception
        end
      end

      def serializable?(include_object = true)
        if self.is_a?(Hash)
          self.all? do |key, value|
            key.serializable?(include_object) && value.serializable?(include_object)
          end
        elsif self.is_a?(Array)
          self.all? do |value|
            value.serializable?(include_object)
          end
        elsif self.is_a?(String) || self.is_a?(Symbol) || self.is_a?(Numeric) ||
          self.is_a?(TrueClass) || self.is_a?(FalseClass) || self.is_a?(NilClass)
          true
        elsif include_object == true
          self.respond_to?(:as_json) && self.as_json.serializable?(include_object)
        else
          false
        end
      end

      def deep_serialize(include_object = true)
        raise TypeError, "Cannot serialize object of type #{self.class}" unless serializable?(include_object)

        case self
        when Hash
          self.to_h.transform_values { |value| value.deep_serialize(include_object) }
        when Array
          self.map { |value| value.deep_serialize(include_object) }
        when String, Symbol, Numeric, TrueClass, FalseClass, NilClass
          self
        else
          if include_object && self.respond_to?(:to_h)
            self.to_h.deep_serialize(include_object)
          elsif include_object && self.respond_to?(:as_json)
            self.as_json.deep_serialize(include_object)
          end
        end
      end
    end
  end
end

Object.include(Steroids::Extensions::ObjectExtension)
