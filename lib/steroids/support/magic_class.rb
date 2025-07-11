module Steroids
  module Support
    class MagicClass
      include Steroids::Support::ErrorMethods

      class << self
        # TODO: Get rid of this.
        # def inherited(subclass)
        #   instance_variables.each do |var|
        #     subclass_variable_value = instance_variable_get(var).dup
        #     subclass.instance_variable_set(var, subclass_variable_value)
        #   end
        # end
      end
    end
  end
end
