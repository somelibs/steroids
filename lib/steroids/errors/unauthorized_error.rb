module Steroids
  module Errors
    class UnauthorizedError < Steroids::Base::Error
      @@message = "You shall not pass! (Unauthorized)"
      @@status = :unauthorized
    end
  end
end
