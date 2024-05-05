module Steroids
  module Errors
    class ConflictError < Steroids::Base::Error
      @@message = "Already exists (Internal conflict)"
      @@status = :conflict
    end
  end
end
