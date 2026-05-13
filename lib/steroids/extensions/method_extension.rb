module Steroids
  module Extensions
    module MethodExtension
      # --------------------------------------------------------------------------------------------
      # Calling
      # --------------------------------------------------------------------------------------------

      # TODO: Use *arguments.extract_options instead!
      def apply(*given_arguments, **given_options, &block)
        applied_arguments = dynamic_arguments_for(given_arguments, given_options)
        applied_options = dynamic_options_for(given_options)
        # `call` works on both Method and Proc; the original `yield` was
        # Proc-only (Method has no `yield` method).
        call(*applied_arguments, **applied_options, &block)
      end

      def dynamic_arguments_for(given_arguments, given_options)
        return given_arguments if rest?

        expected_arguments_count = least_arguments.count
        applied_arguments = if is_a?(Proc) && !lambda?
                              given_arguments.first([expected_arguments_count, given_arguments.size].max)
                            else
                              given_arguments.first([expected_arguments_count, given_arguments.size].min)
                            end
        return applied_arguments if spread? && options.any?

        applied_arguments << given_options if applied_arguments.count < arguments.count && given_options.any?
        applied_arguments
      end

      def dynamic_options_for(given_options)
        return given_options if spread?

        given_options.select { |key| options.include?(key) }
      end

      private def least_arguments
        all_arguments = parameters.select { |key, _v| [:req, :opt].include?(key) }
        required_arguments = all_arguments.reverse.take_while { |element| element.first == :opt }
        required_count = arguments.size - required_arguments.size
        arguments.first(required_count)
      end

      # --------------------------------------------------------------------------------------------
      # Parameters
      # --------------------------------------------------------------------------------------------

      def arguments
        parameters.select { |key, _v| [:req, :opt].include?(key) }.map { |argument| argument.second }
      end

      def options
        parameters.select { |key, _v| [:key, :keyreq].include?(key) }.map { |option| option.second }
      end

      def spread?
        !!parameters.find { |parameter| parameter.first == :keyrest }
      end

      def rest?
        !!parameters.find { |parameter| parameter.first == :rest }
      end
    end
  end
end

Method.include(Steroids::Extensions::MethodExtension)
