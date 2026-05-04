module Steroids
  module Services
    class Base < Steroids::Support::MagicClass
      include Steroids::Support::ServicableMethods
      include Steroids::Support::NoticableMethods

      @@wrap_in_transaction = true
      @@skip_callbacks = false

      class AmbiguousProcessMethodError < Steroids::Errors::Base; end

      class AsyncProcessArgumentError < Steroids::Errors::Base; end

      class RuntimeError < Steroids::Errors::Base
        self.default_message = "Runtime error"
      end

      # --------------------------------------------------------------------------------------------
      # Core public interface
      # --------------------------------------------------------------------------------------------

      def call(*args, **options, &block)
        outcome = nil
        return unless process_method.present?

        @steroids_force = (!!options[:force]) || false
        @steroids_skip_callbacks = (!!options[:skip_callbacks]) || @@skip_callbacks || false
        @steroids_async = options[:async] if options.key?(:async)
        if process_method.name == :async_process
          outcome = schedule_process(*args, **options, &block)
        else
          outcome = exec_process(*args, **options, &block)
        end
      ensure
        if block_given?
          block.apply(self, outcome, noticable: self.noticable, flash_key: self.noticable.flash_key)
        elsif errors.any?
          raise self.noticable.to_exception
        end
      end

      private

      # --------------------------------------------------------------------------------------------
      # Run process
      # --------------------------------------------------------------------------------------------

      def exec_process(*args, **options, &block)
        outcome = process_wrapper do
          run_before_callbacks(*args, **options) unless @steroids_skip_callbacks
          process_method.call.tap do |outcome|
            drop! if !block_given? && errors.any?
            run_after_callbacks(outcome) unless @steroids_skip_callbacks
          end
        end
      rescue StandardError => outcome
        errors.add(outcome.message, outcome)
        if respond_to?(:rescue!, true) || block_given?
          Steroids::Logger.print(outcome)
          send_apply(:rescue!, outcome)
        else
          raise outcome
        end
      ensure
        ensure! if respond_to?(:ensure!, true)
      end

      def schedule_process(*args, **options, &block)
        perform_async = !!(options[:async].ifnil(!Sidekiq.server?))
        if self.respond_to?(:async_process, true)
          AsyncServiceJob.new(
            class_name: self.class.name,
            params: @_steroids_serialized_init_options
          ).tap do |job|
            if async_exec?(perform_async)
              job.enqueue
            elsif self.class.async_only? && options[:async] != false
              errors.add("This job requires a background worker (Sidekiq) to be running")
            else
              exec_process(*args, **options, &block)
            end
          end
        end
      end

      def process_method
        self.class.validate_process_definition!
        @process_method ||= (try_method(:process) || try_method(:async_process))
      end

      def async_exec?(perform_async)
        dev = Rails.env.development? || Rails.env.test?
        !!(perform_async == true && (Sidekiq::ProcessSet.new.any? || !dev))
      rescue RedisClient::CannotConnectError, Errno::ENOENT, Errno::ECONNREFUSED => e
        Steroids::Logger.print(e) if dev
        false
      end

      # --------------------------------------------------------------------------------------------
      # Process wrapper
      # --------------------------------------------------------------------------------------------

      def process_wrapper(&block)
        return block.call unless @@wrap_in_transaction

        ActiveRecord::Base.transaction do
          block.call
        end
      rescue RuntimeError => error
        errors.add(error.message)
      end

      def run_before_callbacks(*args, **options)
        if self.class.steroids_before_callbacks.is_a?(Array)
          self.class.steroids_before_callbacks.each do |callback|
            send_apply(callback, *args, **options)
          end
        end
        send_apply(:before_process, *args, **options)
      end

      def run_after_callbacks(outcome)
        send_apply(:after_process, outcome)
        if self.class.steroids_after_callbacks.is_a?(Array)
          self.class.steroids_after_callbacks.each do |callback|
            send_apply(callback, outcome)
          end
        end
      end

      # --------------------------------------------------------------------------------------------
      # Flow control
      # --------------------------------------------------------------------------------------------

      def drop!(message_or_nil = nil, message: nil)
        unless @steroids_force
          raise RuntimeError.new(
            message: message_or_nil || message,
            errors: errors,
            log: true
          )
        end
      end

      class << self
        def async?
          self.private_instance_methods.include?(:async_process) || self.instance_methods.include?(:async_process)
        end

        def async_only!
          @async_only = true
        end

        def async_only?
          !!@async_only
        end

        def call(*args, **options, &block)
          new(*args, **options).call(&block)
        end

        def new(*arguments, **options)
          validate_process_definition!
          instance = super
          if self.async?
            if arguments.empty? && options.serializable?
              instance.instance_variable_set(:"@_steroids_serialized_init_options", options.deep_serialize)
            else
              raise AsyncProcessArgumentError.new("Async services require serializable options")
            end
          end
          instance
        end

        def steroids_before_callbacks
          @steroids_before_callbacks ||= []
        end

        def steroids_after_callbacks
          @steroids_after_callbacks ||= []
        end

        def validate_process_definition!
          if async? && (self.private_instance_methods.include?(:process) || self.instance_methods.include?(:process))
            raise AmbiguousProcessMethodError.new("Can't define both `process` and `async_process`")
          end
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
