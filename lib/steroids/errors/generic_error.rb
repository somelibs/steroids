module Steroids
  module Errors
    class GenericError < Steroids::Base::Error
      def initialize(options = {})
        super(
          {
            message: options[:message] || "Something went wrong",
          }.merge(options)
        )
      end
    end
  end
end
