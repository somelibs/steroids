module Steroids
  module Errors
    class ForbiddenError < Steroids::Base::Error
      default_message "You shall not pass! (Forbidden)"

      def initialize(options = {})
        super(
          **options,
          status: :forbidden
        )
      end
    end
  end
end
