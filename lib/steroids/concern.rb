module Steroids
  module Concern
    # ----------------------------------------------------------------------- #
    #                      Multiple Included Blocks Error                     #
    # ----------------------------------------------------------------------- #

    class MultipleIncludedBlocks < StandardError #:nodoc:
      def initialize
        super "Cannot define multiple 'included' blocks for a Concern"
      end
    end

    # ----------------------------------------------------------------------- #
    #                                  Extended                               #
    # ----------------------------------------------------------------------- #

    def self.extended(base)
      base.instance_variable_set(:@_dependencies, [])
    end

    # ----------------------------------------------------------------------- #
    #                            Concern: Append features                     #
    # ----------------------------------------------------------------------- #

    def get_proxy(base_class, instance, scope)
      _self = self
      proxy_name = "#{base_class.name.gsub('::', '') + SecureRandom.hex + @scope.to_s.classify}Proxy"
      unless _self.const_defined?(proxy_name)
        proxy_class = Class.new base_class do
          self.table_name = base_class.table_name

          define_method :initialize do |instance|
            super(instance.attributes)
          end

          instance.attributes.each do |key, _attribute|
            define_method key do
              instance.read_attribute(key)
            end

            define_method "#{key}=" do |value|
              instance.write_attribute(key, value)
            end
          end

          native_methods = Class.instance_methods
          active_methods = ActiveRecord::Base.instance_methods
          own_methods = instance_methods - base_class.instance_methods

          instance_methods.each do |method|
            next unless !native_methods.include?(method) && !own_methods.include?(method) &&
                        !active_methods.include?(method) && method != scope

            define_method method do |*args|
              instance.send(method, *args)
            end
          end
        end
        _self.const_set(proxy_name, proxy_class)
      end
      _self.const_get(proxy_name)
    end

    def append_features(base_class)
      _self = self
      if base_class.instance_variable_defined?(:@_dependencies)
        base_class.instance_variable_get(:@_dependencies) << self
        false
      else
        _scope_name = @_scope_name
        _dependencies = @_dependencies
        _included_block = @_included_block

        # ----------------------------------------------------------------------- #
        #                        Ruby native concern handlers                     #
        # ----------------------------------------------------------------------- #

        return false if base_class < self

        super

        # ----------------------------------------------------------------------- #
        #                 Defining the concern scope as a method                  #
        # ----------------------------------------------------------------------- #

        define_method @_scope_name do
          instance = self

          proxy = _self.get_proxy(base_class, instance, _scope_name)

          # ----------------------------------------------------------------------- #
          #                          Proc & Dependency injection                    #
          # ----------------------------------------------------------------------- #

          _dependencies.each { |dependency| proxy.include(dependency) }
          if _self.const_defined?(:ClassMethods)
            proxy.extend const_get(:ClassMethods)
          end
          if _self.instance_variable_defined?(:@_included_block)
            proxy.class_eval(&_included_block)
          end

          # ----------------------------------------------------------------------- #
          #                     Rails & Ruby native concern handlers                #
          # ----------------------------------------------------------------------- #

          @proxy ||= proxy.new(instance)
        end
      end
    end

    def concern(scope, &block)
      if instance_variable_defined?(:@_included_block)
        if @_included_block.source_location != block.source_location
          raise MultipleIncludedBlocks
        end
      else
        @_scope_name = scope
        @_included_block = block
      end
    end

    def class_methods(&class_methods_module_definition)
      mod = const_defined?(:ClassMethods, false) ?
        const_get(:ClassMethods) :
        const_set(:ClassMethods, Module.new)
      mod.module_eval(&class_methods_module_definition)
    end
  end
end
