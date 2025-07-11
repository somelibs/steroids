# frozen_string_literal: true
module Steroids
  module Errors
    # ##############################################################################################
    # Steroids errors
    # ##############################################################################################

    class GenericError < Steroids::Errors::Base
      self.default_message = "Steroids error (Generic)"
      self.default_status = :generic_error
    end

    # ##############################################################################################
    # HTTP Error Codes (API)
    # ##############################################################################################

    # ----------------------------------------------------------------------------------------------
    # BadRequestError
    # ----------------------------------------------------------------------------------------------

    class BadRequestError < Steroids::Errors::Base
      self.default_message = "Request failed (BadRequestError)."
      self.default_status = :bad_request
    end

    # ----------------------------------------------------------------------------------------------
    # ConflictError
    # ----------------------------------------------------------------------------------------------

    class ConflictError < Steroids::Errors::Base
      self.default_message = "Already exists (InternalConflictError)"
      self.default_status = :conflict
    end

    # ----------------------------------------------------------------------------------------------
    # ForbiddenError
    # ----------------------------------------------------------------------------------------------

    class ForbiddenError < Steroids::Errors::Base
      self.default_message = "You shall not pass! (ForbiddenError)"
      self.default_status = :forbidden
    end

    # ----------------------------------------------------------------------------------------------
    # InternalServerError
    # ----------------------------------------------------------------------------------------------

    class InternalServerError < Steroids::Errors::Base
      self.default_message = "Oops, something went wrong (InternalServerError)"
      self.default_status = :internal_server_error
    end

    # ----------------------------------------------------------------------------------------------
    # NotFoundError
    # ----------------------------------------------------------------------------------------------

    class NotFoundError < Steroids::Errors::Base
      self.default_message = "We couldn't find what you were looking for (NotfoundError)"
      self.default_status = :not_found
    end

    # ----------------------------------------------------------------------------------------------
    # NotImplementedError
    # ----------------------------------------------------------------------------------------------

    class NotImplementedError < Steroids::Errors::Base
      self.default_message = "This feature hasn't been implemented yet (NotImplementedError)"
      self.default_status = :not_implemented
    end

    # ----------------------------------------------------------------------------------------------
    # UnauthorizedError
    # ----------------------------------------------------------------------------------------------

    class UnauthorizedError < Steroids::Errors::Base
      self.default_message = "You shall not pass! (Unauthorized)"
      self.default_status = :unauthorized
    end

    # ----------------------------------------------------------------------------------------------
    # UnprocessableEntityError
    # ----------------------------------------------------------------------------------------------

    class UnprocessableEntityError < Steroids::Errors::Base
      self.default_message = "We couldn't understand your request (UnprocessableEntityError)"
      self.default_status = :unprocessable_entity
    end
  end
end
