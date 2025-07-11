module Steroids
  class ErrorSerializer < Steroids::Serializers::Base
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
      [
        @object.message,
        Rails.env.development? && @object.respond_to?(:cause) && @object.cause.present? ?
          @object.cause : nil
      ].compact.join(" - Cause by: ")
    end

    def timestamp
      @object.timestamp
    end
  end
end
