module Steroids
  module Errors
    class GenericError < Steroids::Base::Error
      @@message = "Steroids error (Generic)"
      @@status = :generic_error
    end
  end
end
