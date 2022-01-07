module Steroids
  module Errors
    class NotImplementedError < Steroids::Base::Error
      def initialize(options = {})
        options[:message] ||= "This feature hasn't been implemented yet"
        super(
          **{
            status: :not_implemented,
            key: :not_implemented
          }.merge(options)
        )
      end
    end
  end
end
