module Steroids
  module Base
    class Error < StandardError
      include ActiveModel::Serialization

      @@DEFAULT_MESSAGE = 'An error has occurred while processing your request [Steroids::Base::Error]'

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

      def initialize(status: false, message:, key: nil, errors: nil, data: nil, reference: nil, exception: nil)
        @id = SecureRandom.uuid
        @key = assert_key(key)
        @data = assert_data(data)
        @code = assert_code(status)
        @status = assert_status(status)
        @reference = assert_reference(reference)
        @message = assert_message(exception, message)
        @errors = assert_errors(exception, errors)
        @klass = assert_class(exception)
        @proverb = proverb
        super(@message)
      end

      protected

      def proverb
        begin
          proverbs = Rails.cache.fetch('core/error_proverbs', expires_in: 1.hour) do
            YAML.load_file(Rails.root.join('config/proverbs.yml'))
          end
        rescue StandardError => e
          Utilities::Logger.push(e)
          proverbs = ['One little bug...']
        end
        proverbs.sample
      end

      private

      def assert_class(exception)
        exception&.class
      end

      def assert_status(status)
        status ? Rack::Utils.status_code(status) : false
      end

      def assert_code(status)
        status ? status.to_s : 'error'
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
        message && message.to_s || @@DEFAULT_MESSAGE
      end

      def reflect_on_exception(exception, attribute)
        exception&.respond_to?(attribute) ? exception.message : nil
      end
    end
  end
end
