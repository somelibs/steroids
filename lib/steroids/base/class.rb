module Steroids
  module Base
    class Class
      include Steroids::Concerns::Error
      class << self
        def inherited(subclass)
          instance_variables.each do |var|
            subclass_variable_value = instance_variable_get(var).dup
            subclass.instance_variable_set(var, subclass_variable_value)
          end
        end
      end
    end
  end
end
