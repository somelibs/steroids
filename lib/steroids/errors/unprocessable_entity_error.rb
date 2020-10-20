module Steroids
  module Errors
    class UnprocessableEntityError < Steroids::Base::Error
      def initialize(options = {})
        options[:message] ||= "We couldn't understand your request (Unprocessable entity)"
        super(
          {
            status: :unprocessable_entity,
            key: :unprocessable_entity
          }.merge(options)
        )
      end
    end
  end
end
