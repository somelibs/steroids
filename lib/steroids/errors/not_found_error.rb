module Steroids
  module Errors
    class NotFoundError < Steroids::Base::Error
      default_message "We couldn't find what you were looking for (Not found)"

      def initialize(options = {})
        super(
          **options,
          status: :not_found
        )
      end
    end
  end
end
