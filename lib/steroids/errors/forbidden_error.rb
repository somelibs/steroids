module Steroids
  module Errors
    class ForbiddenError < Steroids::Base::Error
      @@message = "You shall not pass! (Forbidden)"
      @@status = :forbidden
    end
  end
end
