module Steroids
  module Errors
    class NotFoundError < Steroids::Base::Error
      def initialize(options = {})
        super(
          {
            message: options[:message] || "We couldn't find what you were looking for",
            status: :not_found,
            key: :not_found
          }.merge(options)
        )
      end
    end
  end
end
