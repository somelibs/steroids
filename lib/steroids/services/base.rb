module Steroids
  module Services
    class Base < Steroids::Support::MagicClass
      include Steroids::Support::ServicableMethods
      include Steroids::Support::NoticableMethods

      @@wrap_in_transaction = true
      @@skip_callbacks = false

      class AmbiguousProcessMethodError < Steroids::Errors::Base; end

      class RuntimeError < Steroids::Errors::Base
        self.default_message = "Runtime error"
      end

      # --------------------------------------------------------------------------------------------
      # Core public interface
      # --------------------------------------------------------------------------------------------

      def call(*args, **options, &block)
        return unless process_method.present?

        @steroids_force = (!!options[:force]) || false
        @steroids_skip_callbacks = (!!options[:skip_callbacks]) || @@skip_callbacks || false
        if process_method.name == :async_process
          schedule_process(*args, **options, &block)
        else
          exec_process(*args, **options, &block)
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
            abort! if !block_given? && errors.any?
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
        block.apply(self, outcome, noticable: self.noticable) if block_given?
      end

      def schedule_process(*args, **options, &block)
        async_exec = (!!options[:async]) || true
        if self.respond_to?(:async_process, true) && @_steroids_serialized_init_options.present?
          if async_exec?(async_exec)
            AsyncServiceJob.perform_later(
              class_name: self.class.name,
              params: @_steroids_serialized_init_options
            )
          else
            exec_process(*args, **options, &block)
          end
        end
      end

      def process_method
        raise AmbiguousProcessMethodError.new if respond_to?(:process, true) && respond_to?(:async_process, true)

        try_method(:process) || try_method(:async_process)
      end

      def async_exec?(async)
        !!if async == true && (Sidekiq::ProcessSet.new.any? || !Rails.env.development?)
          !(Rails.env.development? || Rails.const_defined?(:Console))
        end
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
        respond_to?(:before_process) && send_apply(:before_process, *args, **options)
      end

      def run_after_callbacks(outcome)
        respond_to?(:after_process) && send_apply(:after_process, outcome)
        if self.class.steroids_after_callbacks.is_a?(Array)
          self.class.steroids_after_callbacks.each do |callback|
            send_apply(callback, outcome)
          end
        end
      end

      # --------------------------------------------------------------------------------------------
      # Flow control
      # --------------------------------------------------------------------------------------------

      def abort!(message_or_nil = nil, message: nil)
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

        def call(*args, **options, &block)
          new(*args, **options).call(&block)
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
