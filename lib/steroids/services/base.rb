module Steroids
  module Services
    class Base < Steroids::Support::MagicClass
      include Steroids::Support::ErrorMethods

      @@wrap_in_transaction = true
      @@skip_callbacks = false

      def call(*args, **options)
        @steroids_force = options[:force] ||= false
        @steroids_skip_callbacks = options[:skip_callbacks] || @@skip_callbacks ||= false
        skip_deferred = options[:skip_deferred] || @@skip_deferred ||= false
        begin
          output = @@wrap_in_transaction ? ActiveRecord::Base.transaction { run_service_process(options, *args) }
            : run_service_process(options, *args)
          output.tap do |output|
            schedule_deferred(output) unless skip_deferred
          end
        ensure
          ensure!
        end
      rescue StandardError => error
        rescue_output = rescue!(error)
        if rescue_output
          Steroids::Logger.print(error)
          rescue_output
        else
          raise error
        end
      end

      def call_async
        @@wrap_in_transaction ?
          ActiveRecord::Base.transaction { run_async_process }
          : run_async_process
      end

      protected

      def process; end

      def ensure!; end

      def before_process(*args); end

      def after_process(*args); end

      def async_process; end

      def rescue!(_exception); end

      private

      def run_service_process(options, *args)
        run_before_callbacks(options, *args) unless @steroids_skip_callbacks
        process.tap do |output|
          run_after_callbacks(output) unless @steroids_skip_callbacks
          if errors? && !@steroids_force
            raise Steroids::Errors::GenericError.new(
              errors: errors,
              log: true
            )
          end
        end
      end

      def exit(message_or_nil = nil, message: nil)
        unless @steroids_force
          raise Steroids::Errors::InternalServerError.new(
            message: message_or_nil || message,
            errors: errors,
            log: true
          )
        end
      end

      def drop(message_or_nil = nil, message: nil)
        unless @steroids_force
          raise Steroids::Errors::BadRequestError.new(
            message: message_or_nil || message,
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

      def run_async_process
        # TODO: Implement before and after callbacks, etc
        # TODO: Prevent service from being both synchronous and asynchronous?
        # e.g. raise errors if both methods are defined?
        async_process
      end

      def schedule_deferred(output)
        if methods.include?(:async_process) && @_steroids_serialized_init_options
          if Rails.env.development? || Rails.const_defined?(:Console)
            call_async
          else
            SteroidsJob.perform_later(
              class_name: self.class.name,
              params: @_steroids_serialized_init_options
            )
          end
        end
      end

      class << self
        attr_accessor :steroids_before_callbacks
        attr_accessor :steroids_after_callbacks

        def call(*args, **options)
          new(*args, **options).call
        end

        def call_async(*args, **options)
          new(*args, **options).call_async
        end

        def new(*arguments, **options)
          instance = super
          if arguments.empty?
             # TODO: check that options are serializable.
            instance.instance_variable_set(:"@_steroids_serialized_init_options", options)
          end
          instance
        end

        def steroids_before_callbacks
          @steroids_before_callbacks ||= []
        end

        def steroids_after_callbacks
          @steroids_after_callbacks ||= []
        end

        protected

        def before_process(method)
          steroids_before_callbacks << method
        end

        def after_process(method)
          steroids_after_callbacks << method
        end
      end
    end
  end
end
