module Steroids
  module Base
    class Error < StandardError
      include ActiveModel::Serialization

      @@DEFAULT_MESSAGE = 'Oops, something went wrong'

      attr_reader :id
      attr_reader :code
      attr_reader :status
      attr_reader :message
      attr_reader :reference
      attr_reader :data
      attr_reader :errors
      attr_reader :key
      attr_reader :proverb
      attr_reader :klass

      def initialize(status: false, message: false, key: nil, errors: nil, data: nil, reference: nil, exception: nil)
        @id = SecureRandom.uuid
        @key = assert_key(key)
        @data = assert_data(data)
        @reference = assert_reference(reference)
        @status = assert_status(exception, status)
        @message = assert_message(exception, message)
        @errors = assert_errors(exception, errors)
        @klass = assert_class(exception)
        @code = assert_code
        @proverb = proverb
        super(@message)
      end

      protected

      def status_from_error(error)
        case error
          when ActiveRecord::RecordNotFound then return :not_found
          when ActionController::RoutingError then return :not_found
          when ActiveRecord::ActiveRecordError then return :bad_request
          when ActiveRecord::RecordInvalid then return :bad_request
          when ActiveModel::ValidationError then return :bad_request
          when ActionDispatch::Http::Parameters::ParseError then return :unprocessable_entity
          when ActiveRecord::ActiveRecordError then return :internal_server_error
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

      def assert_code
        @status ? @status.to_s : 'error'
      end

      def assert_data(data)
        data
      end

      def assert_reference(reference)
        reference ? reference.to_s : 'http_error'
      end

      def assert_key(key)
        Array(key)
      end

      def assert_errors(exception, errors = [])
        exception_errors = Array(reflect_on_exception(exception, :message))
        (Array(errors) + exception_errors).compact
      end

      def assert_message(exception, message)
        exception_message = reflect_on_exception(exception, :message)
        if exception_message && (exception.is_a?(Steroids::Base::Error) ||
                                  self.instance_of?(Steroids::Base::Error))
          exception_message
        elsif message
          message.to_s
        else
          @@DEFAULT_MESSAGE
        end
      end

      def reflect_on_exception(exception, attribute)
        exception&.respond_to?(attribute) ? exception.message : nil
      end
    end
  end
end
