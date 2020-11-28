module Steroids
  module Serializers
    class ErrorSerializer < Steroids::Base::Serializer
      attribute :id
      attribute :code
      attribute :status
      attribute :message
      attribute :proverb
      attribute :reference
      attribute :data
      attribute :errors
      attribute :timestamp
      attribute :exception, if: -> { Rails.env.development? }

      def exception
        @object.klass&.to_s&.demodulize
      end

      def timestamp
        DateTime.now.to_s
      end
    end
  end
end
