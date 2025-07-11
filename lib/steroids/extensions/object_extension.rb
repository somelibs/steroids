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
        method = method(method_name)
        expected_argument_count = method.arguments.count
        expected_options_count = method.options.count
        applied_arguments = arguments.first(expected_argument_count) rescue []
        applied_options = options.select {|key| method.options.include?(key) } rescue {}
        self.send(method_name, *applied_arguments, **applied_options, &block)
      end

      def typed!(expected_type)
        return itself if instance_of?(expected_type) || itself == nil

        message = "Expected #{self.inspect} to be an instance of #{expected_type.inspect}"
        TypeError.new(message).tap do |exception|
          exception.set_backtrace(caller)
          raise exception
        end
      end
    end
  end
end

Object.include(Steroids::Extensions::ObjectExtension)
