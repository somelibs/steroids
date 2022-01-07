module Steroids
  module Errors
    class ConflictError < Steroids::Base::Error
      def initialize(options = {})
        options[:message] ||= "Internal conflict"
        super(
          **{
            status: :conflict,
            key: :conflict
          }.merge(options)
        )
      end
    end
  end
end
