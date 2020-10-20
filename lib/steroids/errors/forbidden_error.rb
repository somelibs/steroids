module Steroids
  module Errors
    class ForbiddenError < Steroids::Base::Error
      def initialize(options = {})
        options[:message] ||= "Your request was denied (Forbidden)"
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
