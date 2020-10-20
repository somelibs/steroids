module Steroids
  module Errors
    class GenericError < Steroids::Base::Error
      def initialize(options = {})
        super(
          {
            message: options[:message] || "Something went wrong (Generic error)",
            status: options[:status] ? Rack::Utils.status_code(status) : false
          }.merge(options)
        )
      end
    end
  end
end
