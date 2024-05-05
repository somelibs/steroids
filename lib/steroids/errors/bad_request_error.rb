module Steroids
  module Errors
    class BadRequestError < Steroids::Base::Error
      @@message = "Request failed (Bad request)."
      @@status = :bad_request
    end
  end
end
