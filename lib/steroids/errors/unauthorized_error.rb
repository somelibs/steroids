module Steroids
  module Errors
    class UnauthorizedError < Steroids::Base::Error
      default_message "You shall not pass! (Unauthorized)"

      def initialize(options = {})
        super(
          **options,
          status: :unauthorized
        )
      end
    end
  end
end
