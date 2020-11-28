module Steroids
  module Base
    class Service < Steroids::Base::Class
      include Steroids::Concerns::Error

      @@wrap_in_transaction = true
      @@skip_callbacks = false

      def call(options = {})
        @output = nil
        @force = options[:force] ||= false
        @skip_callbacks = options[:skip_callbacks] || @@skip_callbacks ||= false
        @@wrap_in_transaction ? ActiveRecord::Base.transaction { process_service } : process_service
        ensure!
        @output
      rescue StandardError => e
        ActiveRecord::Rollback
        ensure!
        rescue_output = rescue!(e)
        raise e unless rescue_output

        Rails.logger.error(e)
        rescue_output
      end

      protected

      def process
        true
      end

      def ensure!
        true
      end

      def rescue!(_exception)
        false
      end

      private

      def process_service
        run_before_callbacks unless @skip_callbacks
        @output = process
        run_after_callbacks unless @skip_callbacks
        if errors? && !@force
          raise Steroids::Errors::GenericError.new(
            message: 'Oops, something went wrong',
            errors: errors
          )
        end
      end

      def exit(message: nil)
        unless @force
          raise Steroids::Errors::InternalServerError.new(
            message: message,
            errors: errors
          )
        end
      end

      def drop(message: nil)
        unless @force
          raise Steroids::Errors::BadRequestError.new(
            message: message,
            errors: errors
          )
        end
      end

      def run_before_callbacks
        if self.class.before_callbacks.is_a?(Array)
          self.class.before_callbacks.each do |callback|
            send(callback)
          end
        end
      end

      def run_after_callbacks
        if self.class.after_callbacks.is_a?(Array)
          self.class.after_callbacks.each do |callback|
            send(callback)
          end
        end
      end

      class << self
        attr_accessor :before_callbacks
        attr_accessor :after_callbacks

        def before_process(method)
          @before_callbacks ||= []
          @before_callbacks << method
        end

        def after_process(method)
          @after_callbacks ||= []
          @after_callbacks << method
        end
      end
    end
  end
end
