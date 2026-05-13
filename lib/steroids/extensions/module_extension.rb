module Steroids
  module Extensions
    module ModuleExtension
      def grundclass
        if singleton_class?
          result = nil
          ObjectSpace.each_object(self) { |obj| result = obj }
          result
        else
          self
        end
      end

      def create_namespace(namespace, value = nil)
        namespace = namespace.to_s.sub(/^::/, '')
        modules = namespace.split('::')
        return self if modules.empty?

        module_name = modules.first
        nested_modules = modules[1..].join('::')
        current_module = if const_defined?(module_name, false)
                           const_get(module_name)
                         else
                           const_set(module_name, Module.new)
                         end

        nested_modules.empty? ? current_module : current_module.create_namespace(nested_modules, value)
      end

      private

      def mixin(method_name)
        if grundclass.methods.include?(method_name)
          grundclass.define_method(method_name) do |*args|
            self.class.send(method_name, *args)
          end
        else
          raise ArgumentError.new("Mixin expects a class method")
        end
      end

      def mixin_alias(alias_name, method_name)
        grundclass.define_method(alias_name) do |*args|
          self.class.send(method_name, *args)
        end
        grundclass.define_singleton_method(alias_name) do |*args|
          send(method_name, *args)
        end
      end
    end
  end
end

Module.include(Steroids::Extensions::ModuleExtension)
