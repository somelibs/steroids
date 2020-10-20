module Steroids
  module Errors
    class InternalServerError < Steroids::Base::Error
      def initialize(options = {})
        options[:message] ||= "Something went wrong (Internal error)"
        super(
          {
            status: :internal_server_error,
            key: :server_error
          }.merge(options)
        )
      end
    end
  end
end
