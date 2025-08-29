module Steroids
  module Extensions
    module MethodExtension
      # --------------------------------------------------------------------------------------------
      # Calling
      # --------------------------------------------------------------------------------------------

      def apply(*given_arguments, **given_options, &block)
        applied_arguments = dynamic_arguments_for(given_arguments, given_options)
        applied_options = dynamic_options_for(given_options)
        self.yield(*applied_arguments, **applied_options, &block)
      end

      def dynamic_arguments_for(given_arguments, given_options)
        return given_arguments if self.rest?

        expected_arguments_count = self.least_arguments.count
        non_nil_arguments_count = given_arguments.take_while(&:present?).count
        applied_arguments = given_arguments.first([expected_arguments_count, non_nil_arguments_count].min)
        return applied_arguments if self.spread? && self.options.any?

        applied_arguments << given_options if applied_arguments.count < self.arguments.count
        applied_arguments
      end

      def dynamic_options_for(given_options)
        return given_options if self.spread?

        given_options.select { |key| self.options.include?(key) }
      end

      private def least_arguments
        all_arguments = self.parameters.select { |key,v| key == :req || key == :opt }
        required_arguments = all_arguments.reverse.take_while { |element| element.first == :opt }
        required_count = arguments.size - required_arguments.size
        arguments.first(required_count)
      end

      # --------------------------------------------------------------------------------------------
      # Parameters
      # --------------------------------------------------------------------------------------------

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

Method.include(Steroids::Extensions::MethodExtension)
