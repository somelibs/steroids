module Steroids
  module Errors
    class NotImplementedError < Steroids::Base::Error
      @@message = "This feature hasn't been implemented yet"
      @@status = :not_implemented
    end
  end
end
