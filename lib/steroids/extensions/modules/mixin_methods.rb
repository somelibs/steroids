module Steroids
  module Extensions
    module Modules
      module MixinMethods
        def grundclass
          self.singleton_class? ? ObjectSpace.each_object(self).to_a.last : self
        end

        private

        def mixin(method_name)
          class_name = grundclass.name.split("::").last rescue nil
          if grundclass.methods.include?(method_name)
            grundclass.define_method(method_name) do |*args|
              self.class.send(method_name, *args)
            end
          elsif klass_name == "ClassMethods"
            raise ArgumentError.new("Can't use mixin on Module ClassMethods. Use included instead.")
          else
            raise ArgumentError.new("Mixin expects a class method")
          end
        end

        def mixin_alias(alias_name, method_name)
          grundclass.define_method(alias_name) do |*args|
            self.class.send(method_name, *args)
          end
          grundclass.define_singleton_method(alias_name) do |*args|
            self.send(method_name, *args)
          end
        end
      end
    end
  end
end

Module.include(Steroids::Extensions::Modules::MixinMethods)
