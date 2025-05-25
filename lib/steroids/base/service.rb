module Steroids
  module Base
    class Service < Steroids::Base::Class
      include Steroids::Concerns::Error

      # NOTE: Does not work, cause it defines it on all inherited class.
      # TODO: Create a Steroids extension for class_instance_attribute
      # class_attribute :steroids_before_callbacks, default: []
      # class_attribute :steroids_after_callbacks, default: []

      @@wrap_in_transaction = true
      @@skip_callbacks = false

      def call(*args, **options)
        @steroids_output = nil
        @steroids_force = options[:force] ||= false
        @steroids_skip_callbacks = options[:skip_callbacks] || @@skip_callbacks ||= false
        @@wrap_in_transaction ?
          ActiveRecord::Base.transaction { process_service(options, *args) }
          : process_service(options, *args)
        ensure!
        @steroids_output
      rescue StandardError => error
        ActiveRecord::Rollback
        ensure!
        rescue_output = rescue!(error)
        unless rescue_output
          raise error
        else
          Steroids::Utils::Logger.print(error)
          rescue_output
        end
      end

      protected

      def process; end

      def ensure!; end

      def before_process(*args); end

      def after_process(*args); end

      def rescue!(_exception); end

      private

      def process_service(options, *args)
        run_before_callbacks(options, *args) unless @steroids_skip_callbacks
        @steroids_output = process
        run_after_callbacks(@steroids_output) unless @steroids_skip_callbacks
        if errors? && !@steroids_force
          raise Steroids::Errors::GenericError.new(
            errors: errors,
            log: true
          )
        end
      end

      def exit(message: nil)
        unless @steroids_force
          raise Steroids::Errors::InternalServerError.new(
            message: message,
            errors: errors,
            log: true
          )
        end
      end

      def drop(message: nil)
        unless @steroids_force
          raise Steroids::Errors::BadRequestError.new(
            message: message,
            errors: errors,
            log: true
          )
        end
      end

      def run_before_callbacks(*args)
        if self.class.steroids_before_callbacks.is_a?(Array)
          self.class.steroids_before_callbacks.each do |callback|
            method(callback).parameters.any? ? send(callback, *args) : send(callback)
          end
        end
        method(:before_process).parameters.any? ? before_process(*args) : before_process
      end

      def run_after_callbacks(output)
        method(:after_process).parameters.any? ? after_process(output) : after_process
        if self.class.steroids_after_callbacks.is_a?(Array)
          self.class.steroids_after_callbacks.each do |callback|
            method(callback).parameters.any? ? send(callback, output) : send(callback)
          end
        end
      end

      class << self
        attr_accessor :steroids_before_callbacks
        attr_accessor :steroids_after_callbacks

        def call(*args, **options)
          new(*args, **options).call
        end

        protected

        def before_process(method)
          @steroids_before_callbacks ||= []
          @steroids_before_callbacks << method
        end

        def after_process(method)
          @steroids_after_callbacks ||= []
          @steroids_after_callbacks << method
        end
      end
    end
  end
end
