module Steroids
  module Extensions
    module Objects
      module InstanceApply
        def instance_apply(*arguments, **options, &block)
          expected_argument_count = block.arguments.count
          expected_options_count = block.options.count
          applied_arguments = arguments[..(expected_argument_count - 1)] rescue []
          applied_options = options.select {|key| self.options.include?(key) } rescue {}
          self.instance_exec(*applied_arguments, **applied_options, &block)
        end
      end
    end
  end
end

Object.include(Steroids::Extensions::Objects::InstanceApply)
