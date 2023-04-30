module Steroids
  module Serializers
    class ErrorSerializer < Steroids::Base::Serializer
      attribute :id
      attribute :code
      attribute :status
      attribute :message
      attribute :quote
      attribute :errors
      attribute :timestamp

      attributes :exception,
                 :message,
                 if: -> { Rails.env.development? }

      def exception
        if @object.respond_to?(:cause) && @object.cause.present?
          @object.cause.class.to_s&.demodulize
        else
          @object.class.to_s&.demodulize
        end
      end

      def message
        if Rails.env.development? && @object.respond_to?(:cause) && @object.cause.present?
          @object.cause.message
        else
          @object.message
        end
      end

      def timestamp
        @object.timestamp
      end
    end
  end
end
