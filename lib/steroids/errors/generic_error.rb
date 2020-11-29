module Steroids
  module Errors
    class GenericError < Steroids::Base::Error
      def initialize(options = {})
        super(
          {
            message: options[:message] || "Oops, something went wrong",
          }.merge(options)
        )
      end
    end
  end
end
