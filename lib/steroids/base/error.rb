module Steroids
  module Base
    class Error < StandardError
      include ActiveModel::Serialization

      @@DEFAULT_MESSAGE = 'Something went wrong'

      attr_reader :id
      attr_reader :code
      attr_reader :status
      attr_reader :errors
      attr_reader :key
      attr_reader :quote
      attr_reader :timestamp
      attr_reader :logged

      def initialize(
        status: false,
        message: false,
        errors: nil,
        code: nil,
        cause: nil,
        log: false,
        **splat
      )
        set_backtrace(cause&.backtrace || backtrace_locations)
        @timestamp = DateTime.now.to_s
        @id = SecureRandom.uuid
        @status = assert_status(cause, status)
        @message = assert_message(cause, message)
        @errors = assert_errors(cause, errors)
        @code = assert_code(code)
        @quote = quote
        self.log! if log
        super(**splat, message: @message, cause: cause)
      end

      def to_json
        Steroids::Serializers::ErrorSerializer.new(self).to_json
      end

      def log!
        Steroids::Utils::Logger.print(self)
        @logged = true
      end

      protected

      def status_from_error(error)
        own_status = reflect_on(error, :status)
        return own_status if own_status

        # Improvement needed
        # See https://stackoverflow.com/questions/25892194/does-rails-come-with-a-not-authorized-exception
        case error
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
          else return :internal_server_error
        end
      end

      def quote
        begin
          path = File.join(Steroids.path, 'misc/quotes.yml')
          quotes = Rails.cache.fetch('steroids/quotes') do
            YAML.load_file(path)
          end
        rescue StandardError => e
          Rails.logger.error(e)
          quotes = ['One little bug...']
        end
        quotes.sample
      end

      private

      def assert_status(cause, status)
        status_code = status || status_from_error(cause)
        Rack::Utils.status_code(status_code)
      end

      def assert_code(code)
        code || @status ? @status.to_s : 'unknown_error'
      end

      def assert_key(key)
        Array(key)
      end

      def assert_errors(cause, errors = [])
        cause_errors = reflect_on(cause, :errors) || []
        active_model = reflect_on(cause, :model) || reflect_on(cause, :record)
        validations_errors = reflect_on(active_model, :errors)&.to_a || []
        [Array(errors), cause_errors, validations_errors].flatten.compact.uniq
      end

      def assert_message(cause, message)
        cause_message = reflect_on(cause, :message)
        if cause_message && (cause.is_a?(Steroids::Base::Error) ||
                                  self.instance_of?(Steroids::Base::Error))
          cause_message
        elsif message
          message.to_s
        else
          @@DEFAULT_MESSAGE
        end
      end

      def reflect_on(instance, attribute)
        instance&.respond_to?(attribute) ? instance.public_send(attribute) : nil
      end
    end
  end
end
