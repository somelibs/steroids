module Steroids
  module Errors
    module Context
      extend ActiveSupport::Concern

      included do |base|
        private

        def define_instance_variables_for(
          message_string,
          status: false,
          message: false,
          errors: nil,
          code: nil,
          cause: nil,
          context: false,
          log: false,
          **splat
        )
          @timestamp = DateTime.now
          @id = SecureRandom.uuid
          @message = assert_message(cause, message_string || message)
          @context = assert_context(cause, context)
          @errors = assert_errors(cause, errors)
          @status = assert_status(cause, status)
          @code = assert_code(code)
          @record = assert_record(cause)
          @quote = quote
          @cause = cause
        end

        # ------------------------------------------------------------------------------------------
        # DERIVE ERROR ATTRIBUTES
        # ------------------------------------------------------------------------------------------

        def assert_message(cause, message)
          message || self.default_message
        end

        def assert_context(cause, context)
          context || reflect_on(cause, :context)
        end

        def assert_status(cause, status)
          status || reflect_on(cause, :status) || assert_status_from_error(cause) || self.default_status || :unknown_error
        end

        def assert_status_from_error(cause)
          error_class = cause.is_a?(Exception) ? cause.class : self.class
          ActionDispatch::ExceptionWrapper.rescue_responses[error_class.name] || :internal_server_error
        end

        def assert_code(status)
          status ? Rack::Utils.status_code(status) : 520
        end

        def assert_errors(cause, errors = [])
          cause_errors = reflect_on(cause, :errors) || []
          record_instance = reflect_on(cause, :record)
          validations_errors = Array(reflect_on(record_instance, :errors)) || []
          [Array(errors), cause_errors, validations_errors].flatten.compact.uniq
        end

        def assert_record(cause, errors = [])
          reflect_on(cause, :record)
        end
      end
    end
  end
end
