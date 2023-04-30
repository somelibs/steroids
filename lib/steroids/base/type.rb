module Steroids
  module Base
    class Type < Steroids::Base::Model
      def import(_options, _object = {})
        raise Steroids::Errors::InternalServerError.new(
          message: name + ': Import not implemented'
        )
      end

      def to_s
        if attributes.present?
          values.to_json
        else
          ''
        end
      end

      def values
        hash = {}
        attributes.each do |attribute|
          hash[attribute] = read_attribute_for_serialization(attribute)
        end
        hash
      end

      def validate
        validate_required && super
      end

      def validate!
        validate_required!
        super
      end

      def validate_required
        missing_attributes.empty?
      end

      def validate_required!
        unless validate_required
          raise Steroids::Errors::InternalServerError.new(
            message: self.class.name + ': Missing required attributes ' + missing_attributes.to_s
          )
        end
      end

      def missing_attributes
        self.class.missing_attributes_for(values)
      end

      class << self
        def required_attributes
          @required_attributes ||= []
        end

        def requires(attribute, _options = {})
          unless required_attributes.include?(attribute)
            required_attributes << attribute
          end
        end

        def import(options, object)
          instance = new({}, true)
          instance.import(options, object) if options.present?
          instance
        rescue Exception => e
          raise Steroids::Errors::InternalServerError.new(
            cause: e,
            message: 'Import failed'
          )
        end

        def missing_attributes_for(payload)
          missing_attributes = []
          required_attributes.each do |attribute|
            unless payload.keys.include?(attribute) && !payload[attribute].nil?
              missing_attributes << attribute
            end
          end
          missing_attributes
        end

        def validate_required(payload)
          missing_attributes_for(payload).empty?
        end

        def validate_required!(payload)
          unless validate_required(payload)
            raise Steroids::Errors::InternalServerError.new(
              message: name + ': Missing required attributes ' + missing_attributes_for(payload).to_s
            )
          end
        end

        def new(options = {}, ignore_required = false)
          validate_required!(options) unless ignore_required
          super(options)
        end
      end
    end
  end
end
