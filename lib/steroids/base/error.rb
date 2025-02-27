module Steroids
  module Base
    class Error < StandardError
      include ActiveModel::Serialization
      @@message = "Oops, something went wrong (Unknown error)"
      @@status = :internal_server_error

      attr_reader :id
      attr_reader :message
      attr_reader :cause
      attr_reader :code
      attr_reader :status
      attr_reader :errors
      attr_reader :quote
      attr_reader :record
      attr_reader :context
      attr_reader :timestamp
      attr_reader :logged

      def initialize(
        message_string = nil,
        status: false,
        message: false,
        errors: nil,
        code: nil,
        cause: nil,
        context: false,
        log: false,
        **splat
      )
        @caller = caller
        super(**splat, message: message, cause: cause)
        set_backtrace(cause&.backtrace || backtrace_locations || caller)
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
        log ? self.log! : self.quiet_log
      end

      def to_json
        Steroids::Serializers::ErrorSerializer.new(self).to_json
      end

      def log!
        Steroids::Utils::Logger.print(self)
        @logged = true
      end

      def cause_message
        if cause
          reflect_on(cause, :original_message) || reflect_on(cause, :message)
        end
      end

      protected

      def quote
        begin
          path = File.join(Steroids.root_path, "misc/quotes.yml")
          quotes = Rails.cache.fetch("steroids/quotes") do
            YAML.load_file(path)
          end
        rescue StandardError => e
          Rails.logger.error(e)
          quotes = ["One little bug..."]
        end
        quotes.sample
      end

      private

      def assert_message(cause, message)
        message || @@message
      end

      def assert_context(cause, context)
        context || reflect_on(cause, :context)
      end

      def assert_status(cause, status)
        status || reflect_on(cause, :status) || assert_status_from_error(cause) || @@status || :unknown_error
      end

      def assert_status_from_error(cause)
        error_class = cause.is_a?(Exception) ? cause.class : self.class
        # Improvement needed
        # See https://stackoverflow.com/questions/25892194/does-rails-come-with-a-not-authorized-exception
        case error_class
          when ActiveRecord::StaleObjectError then return :conflict
          when ActiveRecord::RecordNotFound then return :not_found
          when ActiveRecord::ActiveRecordError then return :bad_request
          when ActiveRecord::RecordInvalid then return :bad_request
          when ActionController::RoutingError then return :not_found
          when ActionController::ParameterMissing then return :bad_request
          when ActionController::UnknownFormat then return :not_acceptable
          when ActionController::NotImplemented then return :not_implemented
          when ActionController::UnknownHttpMethod then return :method_not_allowed
          when ActionController::MethodNotAllowed then return :method_not_allowed
          when ActionController::InvalidAuthenticityToken then return :unprocessable_entity
          when ActionDispatch::Http::Parameters::ParseError then return :unprocessable_entity
          when ActiveRecord::RecordNotSaved then return :unprocessable_entity
          when ActiveModel::ValidationError then return :bad_request
        end
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

      def reflect_on(cause, key)
        logged = cause.respond_to?(:logged) && cause.logged
        cause.respond_to?(key) && logged != true ? cause.public_send(key) : nil
      end

      def quiet_log
        Steroids::Utils::Logger.print(
          "#{Rainbow("▶").magenta} #{Rainbow(self.class.name).red} -- #{Rainbow(self.message).magenta} (quiet)",
          verbosity: :concise,
          format: :raw
        )
      end
    end
  end
end
