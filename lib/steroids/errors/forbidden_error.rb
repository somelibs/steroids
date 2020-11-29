module Steroids
  module Errors
    class ForbiddenError < Steroids::Base::Error
      def initialize(options = {})
        options[:message] ||= "Forbidden"
        super(
          {
            status: :forbidden,
            key: :forbidden
          }.merge(options)
        )
      end
    end
  end
end
