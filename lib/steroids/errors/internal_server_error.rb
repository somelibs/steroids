module Steroids
  module Errors
    class InternalServerError < Steroids::Base::Error
      @@message = "Oops, something went wrong (Internal error)"
      @@status = :internal_server_error
    end
  end
end
