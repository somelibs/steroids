module Steroids
  module Errors
    class BadRequestError < Steroids::Base::Error
      def initialize(options = {})
        options[:message] ||= 'Bad request'
        super(
          {
            status: :bad_request,
            key: :bad_request
          }.merge(options)
        )
      end
    end
  end
end
