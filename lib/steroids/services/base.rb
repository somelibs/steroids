module Steroids
  module Services
    class Base < Steroids::Support::MagicClass
      include Steroids::Support::ErrorMethods

      @@wrap_in_transaction = true
      @@skip_callbacks = false

      class RuntimeError < Steroids::Errors::Base; end

      # --------------------------------------------------------------------------------------------
      # Core public interface
      # --------------------------------------------------------------------------------------------

      def call(*args, **options, &block)
        @steroids_force = (!!options[:force]) || false
        @steroids_skip_callbacks = (!!options[:skip_callbacks]) || @@skip_callbacks || false
        skip_deferred = (!!options[:skip_deferred]) || @@skip_deferred ||= false
        async_exec = (!!options[:async]) || true
        begin
          output = @@wrap_in_transaction ? ActiveRecord::Base.transaction { exec_process(options, *args) }
            : exec_process(options, *args)
          output.tap do |output|
            schedule_deferred(output, async_exec:) unless skip_deferred
          end
        ensure
          ensure! if respond_to?(:ensure!)
          block.apply(self) if block_given?
        end
      rescue StandardError, RuntimeError => error
        rescue_output = respond_to?(:rescue!) && send_apply(:rescue!, error)
        if rescue_output
          Steroids::Logger.print(error)
          rescue_output
        else
          raise error
        end
      end

      def call_async
        @@wrap_in_transaction ?
          ActiveRecord::Base.transaction { exec_async_process }
          : exec_async_process
      end

      private

      # --------------------------------------------------------------------------------------------
      # Run process
      # --------------------------------------------------------------------------------------------

      def exec_process(options, *args)
        return unless respond_to?(:process)

        run_before_callbacks(options, *args) unless @steroids_skip_callbacks
        process.tap do |output|
          run_after_callbacks(output) unless @steroids_skip_callbacks
          if any_errors? && !@steroids_force
            raise Steroids::Errors::RuntimeError.new(
              errors: errors,
              log: true
            )
          end
        end
      end

      def run_before_callbacks(*args)
        if self.class.steroids_before_callbacks.is_a?(Array)
          self.class.steroids_before_callbacks.each do |callback|
            send_apply(callback, output)
          end
        end
        respond_to?(:before_process) && send_apply(:before_process, *args)
      end

      def run_after_callbacks(output)
        respond_to?(:after_process) && send_apply(:after_process, output)
        if self.class.steroids_after_callbacks.is_a?(Array)
          self.class.steroids_after_callbacks.each do |callback|
            send_apply(callback, output)
          end
        end
      end

      # --------------------------------------------------------------------------------------------
      # Run Async process
      # --------------------------------------------------------------------------------------------

      def async_exec?(async)
        !!if async == true && (Sidekiq::ProcessSet.new.any? || !Rails.env.development?)
          !(Rails.env.development? || Rails.const_defined?(:Console))
        end
      end

      def schedule_deferred(output, async_exec:)
        if methods.include?(:async_process) && @_steroids_serialized_init_options
          if async_exec?(async_exec)
            AsyncServiceJob.perform_later(
              class_name: self.class.name,
              params: @_steroids_serialized_init_options
            )
          else
            call_async
          end
        end
      end

      def exec_async_process
        return unless respond_to?(:async_process)
        # TODO: Implement before and after callbacks, etc
        # TODO: Prevent service from being both synchronous and asynchronous?
        # e.g. raise errors if both methods are defined?
        async_process
      end

      # --------------------------------------------------------------------------------------------
      # Flow control
      # --------------------------------------------------------------------------------------------

      def drop(message_or_nil = nil, message: nil)
        unless @steroids_force
          raise RuntimeError.new(
            message: message_or_nil || message,
            errors: errors,
            log: true
          )
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
