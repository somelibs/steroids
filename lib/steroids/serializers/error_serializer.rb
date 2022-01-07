module Steroids
  module Serializers
    class ErrorSerializer < Steroids::Base::Serializer
      attribute :id
      attribute :code
      attribute :status
      attribute :message
      attribute :quote
      attribute :context
      attribute :errors
      attribute :timestamp

      attributes :exception,
                 :true_message,
                 if: -> { Rails.env.development? }

      def exception
        @object.klass&.to_s&.demodulize
      end

      def true_message
        @object.true_message || false
      end

      def timestamp
        @object.timestamp
      end
    end
  end
end
