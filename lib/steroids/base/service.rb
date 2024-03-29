module Steroids
  module Base
    class Service < Steroids::Base::Class
      include Steroids::Concerns::Error

      @@wrap_in_transaction = true
      @@skip_callbacks = false

      def call(options = {}, *args)
        @output = nil
        @force = options[:force] ||= false
        @skip_callbacks = options[:skip_callbacks] || @@skip_callbacks ||= false
        @@wrap_in_transaction ?
          ActiveRecord::Base.transaction { process_service(options, *args) }
          : process_service(options, *args)
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

      def process; end

      def ensure!; end

      def before_process(*args); end

      def after_process(*args); end

      def rescue!(_exception); end

      private

      def process_service(options, *args)
        run_before_callbacks(options, *args) unless @skip_callbacks
        @output = process
        run_after_callbacks(@output) unless @skip_callbacks
        if errors? && !@force
          raise Steroids::Errors::GenericError.new(
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

      def run_before_callbacks(*args)
        if self.class.before_callbacks.is_a?(Array)
          self.class.before_callbacks.each do |callback|
            send(callback, *args)
          end
        end
        method(:before_process).parameters.any? ? before_process(*args) : before_process
      end

      def run_after_callbacks(output)
        method(:after_process).parameters.any? ? after_process(output) : after_process
        if self.class.after_callbacks.is_a?(Array)
          self.class.after_callbacks.each do |callback|
            send(callback, output)
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
