module Steroids
  module Extensions
    module MethodExtension
      # --------------------------------------------------------------------------------------------
      # Calling
      # --------------------------------------------------------------------------------------------

      def apply(*arguments, **options, &block)
        expected_argument_count = arguments.count
        expected_options_count = options.count
        applied_arguments = arguments.first(expected_argument_count) rescue []
        applied_options = options.select {|key| self.options.include?(key) } rescue {}
        self.call(*arguments, **options, &block)
      end

      private def applied_arguments(arguments)
        return arguments.compact_blank if method.rest?

        expected_arguments_count = self.least_arguments.count
        non_nil_arguments_count = given_arguments.take_while(&:present?).count
        given_arguments.first([expected_arguments_count, non_nil_arguments_count].max)
      rescue
        []
      end

      # --------------------------------------------------------------------------------------------
      # Parameters
      # --------------------------------------------------------------------------------------------

      def arguments
        self.parameters.select { |key,v| key == :req || key == :opt }.map { |argument| argument.second }
      end

      def least_arguments
        all_arguments = self.parameters.select { |key,v| key == :req || key == :opt }
        required_arguments = all_arguments.reverse.take_while { |element| element.first == :opt }
        required_count = arguments.size - required_arguments.size
        arguments.first(required_count)
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

Method.include(Steroids::Extensions::MethodExtension)
