module Steroids
  module Errors
    class ConflictError < Steroids::Base::Error
      default_message "Already exists (Internal conflict)"

      def initialize(options = {})
        super(
          **options,
          status: :conflict
        )
      end
    end
  end
end
