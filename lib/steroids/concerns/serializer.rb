module Steroids
  module Concerns
    module Serializer
      extend ActiveSupport::Concern
      included do
        def initialize(object, options = {})
          options.each { |name, value| instance_variable_set("@#{name}", value) }
          super(object, options)
        end

        def serializable_hash(adapter_options = nil, options = {}, adapter_instance = self.class.serialization_adapter_instance)
          if @object
            hash = super
            hash.each { |key, value| hash.delete(key) if value.nil? }
            hash
          end
        end

        def json_key
          'root'
        end

        protected

        def parse_options
          options ||= @instance_options ||= {}
          options[:params]&.each do |key, value|
            begin
              case options[:params][key]
                when 'true'
                  options[:params][key] = true
                when 'false'
                  options[:params][key] = false
                when /^[-+]?[1-9]([0-9]*)?$/
                  options[:params][key] = Integer(value)
              end
            rescue => exception
            end
          end
          options
        end

        def options
          options ||= parse_options
        end

        def render(data, options = {})
          if options[:serializer]
            klass = Object.const_get(options[:serializer])
            klass.new(data, self.options.merge(options))
          else
            ActiveModel::Serializer.get_serializer_for(data.class.name)
          end
        end

        class << self
          # Awaiting PR: https://github.com/rails-api/active_model_serializers/pull/2145
          # and https://github.com/rails-api/active_model_serializers/pull/2148
          def attributes(*attrs, **options)
            options = options.except(:key)
            attrs = attrs.first if attrs.first.class == Array
            attrs.each do |attr|
              attribute(attr, options)
            end
          end
        end
      end
    end
  end
end
