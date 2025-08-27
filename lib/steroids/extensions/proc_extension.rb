module Steroids
  module Extensions
    module ProcExtension
      require "ruby2ruby"
      require "ruby_parser"
      require "method_source"

      def apply(*arguments, **options, &block)
        expected_argument_count = arguments.count
        expected_options_count = options.count
        applied_arguments = arguments.first(expected_argument_count) rescue []
        applied_options = options.select {|key| self.options.include?(key) } rescue {}
        self.call(*arguments, **options, &block)
      end

      def arguments
        self.parameters.select { |key,v| key == :req || key == :opt }.map { |argument| argument.second }
      end

      def options
        self.parameters.select { |key,v| key == :key || key == :keyreq }.map { |option| option.second }
      end

      def spread?
        !!self.parameters.find { |parameter| parameter.first == :keyrest }
      end

      def rest?
        !!self.parameters.find { |parameter| parameter.first == :rest }
      end
    end
  end
end

Proc.include(Steroids::Extensions::ProcExtension)
