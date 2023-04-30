module Steroids
  module Errors
    class BadRequestError < Steroids::Base::Error
      default_message "Request failed (Bad request)."

      def initialize(options = {})
        super(
          **options,
          status: :bad_request
        )
      end
    end
  end
end
