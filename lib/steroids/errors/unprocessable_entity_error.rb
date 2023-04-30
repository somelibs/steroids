module Steroids
  module Errors
    class UnprocessableEntityError < Steroids::Base::Error
      default_message "We couldn't understand your request (Unprocessable entity)"

      def initialize(**options)
        super(
          **options,
          status: :unprocessable_entity
        )
      end
    end
  end
end
