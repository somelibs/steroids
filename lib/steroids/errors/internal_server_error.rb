module Steroids
  module Errors
    class InternalServerError < Steroids::Base::Error
      default_message "Oops, something went wrong (Internal error)"

      def initialize(options)
        super(
          **options,
          status: :internal_server_error
        )
      end
    end
  end
end
