module Steroids
  module Errors
    class UnprocessableEntityError < Steroids::Base::Error
      @@message = "We couldn't understand your request (Unprocessable entity)"
      @@status = :unprocessable_entity
    end
  end
end
