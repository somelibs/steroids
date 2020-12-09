module Steroids
  module Base
    class Error < StandardError
      include ActiveModel::Serialization

      @@DEFAULT_MESSAGE = 'Something went wrong'

      attr_reader :id
      attr_reader :code
      attr_reader :status
      attr_reader :message
      attr_reader :context
      attr_reader :errors
      attr_reader :key
      attr_reader :proverb
      attr_reader :klass
      attr_reader :true_message
      attr_reader :timestamp

      def initialize(status: false, message: false, key: nil, errors: nil, context: nil, reference: nil, code: nil, exception: nil)
        @timestamp = DateTime.now.to_s
        @id = SecureRandom.uuid
        @key = assert_key(key)
        @context = assert_context(context)
        @status = assert_status(exception, status)
        @message = assert_message(exception, message)
        @true_message = assert_true_message(exception)
        @errors = assert_errors(exception, errors)
        @klass = assert_class(exception)
        @code = assert_code(code)
        @proverb = proverb
        super(@message)
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

      def proverb
        begin
          path = File.join(Steroids.path, 'misc/proverbs.yml')
          proverbs = Rails.cache.fetch('steroids/proverbs') do
            YAML.load_file(path)
          end
        rescue StandardError => e
          Rails.logger.error(e)
          proverbs = ['One little bug...']
        end
        proverbs.sample
      end

      private

      def assert_class(exception)
        exception&.class
      end

      def assert_status(exception, status)
        status_code = status || status_from_error(exception)
        Rack::Utils.status_code(status_code)
      end

      def assert_code(code)
        code || @status ? @status.to_s : 'unknown_error'
      end

      def assert_context(context)
        context
      end

      def assert_key(key)
        Array(key)
      end

      def assert_errors(exception, errors = [])
        exception_errors = reflect_on(exception, :errors) || []
        active_model = reflect_on(exception, :model) || reflect_on(exception, :record)
        validations_errors = reflect_on(active_model, :errors)&.to_a || []
        (Array(errors) + exception_errors + validations_errors).compact
      end

      def assert_true_message(exception)
        true_msg = reflect_on(exception, :true_message) || reflect_on(exception, :message)
        true_msg != @message ? true_msg : nil
      end

      def assert_message(exception, message)
        exception_message = reflect_on(exception, :message)
        if exception_message && (exception.is_a?(Steroids::Base::Error) ||
                                  self.instance_of?(Steroids::Base::Error))
          exception_message
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
