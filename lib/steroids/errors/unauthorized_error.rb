module Steroids
  module Errors
    class UnauthorizedError < Steroids::Base::Error
      def initialize(options = {})
        options[:message] ||= 'You shall not pass! (Unauthorized)'
        super(
          **{
            status: :unauthorized,
            key: :unauthorized
          }.merge(options)
        )
      end
    end
  end
end
