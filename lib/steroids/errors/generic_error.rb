module Steroids
  module Errors
    class GenericError < Steroids::Base::Error
      default_message "Steroids error (Generic)"

      def initialize(options = {})
        super(
          **options,
          message: options[:message]
        )
      end
    end
  end
end
