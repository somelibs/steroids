module Steroids
  module Errors
    class NotFoundError < Steroids::Base::Error
      @@message = "We couldn't find what you were looking for (Not found)"
      @@status = :not_found
    end
  end
end
