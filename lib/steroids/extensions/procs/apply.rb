module Steroids
  module Extensions
    module Procs
      module Apply
        def apply(*arguments,**options,&block)
          expected_argument_count = arguments.count
          expected_options_count = options.count
          applied_arguments = arguments[..(expected_argument_count - 1)] rescue []
          applied_options = options.select {|key| self.options.include?(key) } rescue {}
          self.call(*arguments, **options, &block)
        end

        def arguments
          self.parameters.select { |key,v| key == :req || key == :opt }.map { |argument| argument.second }
        end

        def options
          self.parameters.select { |key,v| key == :key || key == :keyreq }.map { |option| option.second }
        end
      end
    end
  end
end

Proc.include(Steroids::Extensions::Procs::Apply)
