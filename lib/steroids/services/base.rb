module Steroids
  module Services
    class Base < Steroids::Support::MagicClass
      include Steroids::Support::ServicableMethods
      include Steroids::Support::NoticableMethods

      @@wrap_in_transaction = true
      @@skip_callbacks = false

      # Init-time options that are NOT forwarded to `initialize`, but instead
      # control the .call invocation. Anything else passed at the class entry
      # point flows into the service's `initialize(**options)`.
      CONTROL_OPTIONS = [:force, :skip_callbacks].freeze

      # Argument-position safe set for `call_async` serializability validation —
      # values whose presence in init options is unambiguously serializable by
      # ActiveJob's GlobalID / type registry.
      PRIMITIVE_SERIALIZABLE = [
        String, Symbol, Numeric, TrueClass, FalseClass, NilClass,
        Date, Time, DateTime
      ].freeze

      class AsyncOnlyError < Steroids::Errors::Base
        self.default_message = "Service is marked async_only! — must be enqueued via .call_async"
      end

      class NonSerializableArgumentError < Steroids::Errors::Base
        self.default_message = "Service args contain values that cannot be serialized for background execution"
      end

      class RuntimeError < Steroids::Errors::Base
        self.default_message = "Runtime error"
      end

      # --------------------------------------------------------------------------------------------
      # Instance API — `.call` runs `process` inline with the configured callbacks
      # and transaction wrap. The class-level `.call` / `.call_async` entry points
      # below delegate here.
      # --------------------------------------------------------------------------------------------

      def call(**options, &block)
        outcome = nil
        return unless process_method.present?

        @steroids_force = !!options[:force] || false
        @steroids_skip_callbacks = !!options[:skip_callbacks] || @@skip_callbacks || false
        outcome = exec_process(&block)
      ensure
        if block_given?
          block.apply(self, outcome, noticable: noticable, flash_key: noticable.flash_key)
        elsif errors.any?
          raise noticable.to_exception
        end
      end

      private

      # --------------------------------------------------------------------------------------------
      # Run process inline (with callbacks, transaction, error capture).
      # --------------------------------------------------------------------------------------------

      def exec_process
        process_wrapper do
          run_before_callbacks unless @steroids_skip_callbacks
          process_method.call.tap do |outcome|
            drop! if !block_given? && errors.any?
            run_after_callbacks(outcome) unless @steroids_skip_callbacks
          end
        end
      rescue => e
        errors.add(e.message, e)
        report_error!(e)
        if respond_to?(:rescue!, true) || block_given?
          Steroids::Logger.print(e)
          send_apply(:rescue!, e)
        else
          raise e
        end
      ensure
        ensure! if respond_to?(:ensure!, true)
      end

      # --------------------------------------------------------------------------------------------
      # Observability hook
      # --------------------------------------------------------------------------------------------
      # Push handled exceptions through the agnostic `Steroids::ErrorReporter` seam.
      # Errors whose class opts out via `report_to_observability = false` are skipped;
      # everything else (raw 3rd-party errors and Steroids errors that haven't opted out)
      # is forwarded to `Rails.error.report` and on to whatever the parent app subscribed.
      #
      # Called automatically by `exec_process` for any rescued StandardError. Subclasses
      # can also call it explicitly from inside their own rescue blocks (where the
      # service caught the exception itself) to keep observability without re-raising.
      # Extra keyword args are forwarded as context tags (e.g. `scope:`, ids of the
      # records involved, etc.).
      def report_error!(outcome, **context)
        return if outcome.respond_to?(:report_to_observability) && outcome.report_to_observability == false

        Steroids::ErrorReporter.report_once!(outcome, service: self.class.name, **context)
      end
      alias report_to_observability! report_error!

      def process_method
        @process_method ||= try_method(:process)
      end

      # --------------------------------------------------------------------------------------------
      # Process wrapper
      # --------------------------------------------------------------------------------------------

      def process_wrapper(&block)
        return block.call unless @@wrap_in_transaction

        ActiveRecord::Base.transaction do
          block.call
        end
      rescue RuntimeError => e
        errors.add(e.message)
      end

      def run_before_callbacks
        if self.class.steroids_before_callbacks.is_a?(Array)
          self.class.steroids_before_callbacks.each do |callback|
            send_apply(callback)
          end
        end
        send_apply(:before_process)
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
          raise message: message_or_nil || message,
                errors: errors,
                log: true.to_s
        end
      end

      class << self
        # ------------------------------------------------------------------------------------------
        # Class API
        # ------------------------------------------------------------------------------------------
        #
        # `.call`        → run `process` inline. Raises on async_only! services.
        # `.call_sync`   → alias for `.call` (explicit at call sites that read better with it).
        # `.call_async`  → enqueue Steroids::AsyncServiceJob. Validates serializability of init
        #                  args eagerly so non-serializable values fail fast at the call site
        #                  (clear error listing each offending arg + class) instead of blowing up
        #                  inside the worker.
        #
        # Init args vs control flags: any keyword listed in CONTROL_OPTIONS
        # (`force:`, `skip_callbacks:`) is routed to the instance `.call`; everything else flows
        # into `initialize(**options)`.
        # ------------------------------------------------------------------------------------------

        def call(*args, **options, &block)
          if async_only?
            raise AsyncOnlyError.new(
              "#{name} is marked `async_only!` — use `#{name}.call_async` instead. " \
              "`.call` / `.call_sync` run inline, which is forbidden for this service " \
              "(typically because the work is too long for the request thread)."
            )
          end

          init_opts, ctrl_opts = split_options(options)
          new(*args, **init_opts).call(**ctrl_opts, &block)
        end
        alias call_sync call

        def call_async(*args, **options)
          if args.any?
            raise ArgumentError.new(
              "#{name}.call_async does not accept positional arguments — pass keyword args only " \
              "so they can be serialized for background execution."
            )
          end

          init_opts, ctrl_opts = split_options(options)
          validate_serializable!(init_opts)

          Steroids::AsyncServiceJob.perform_later(
            class_name: name,
            params: init_opts.deep_serialize,
            control: ctrl_opts
          )
        end

        # ------------------------------------------------------------------------------------------
        # Class macros
        # ------------------------------------------------------------------------------------------

        def async_only!
          @async_only = true
        end

        def async_only?
          !!@async_only
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

        private

        # ------------------------------------------------------------------------------------------
        # Internals
        # ------------------------------------------------------------------------------------------

        def split_options(options)
          ctrl = {}
          init = {}
          options.each do |key, value|
            (CONTROL_OPTIONS.include?(key) ? ctrl : init)[key] = value
          end
          [init, ctrl]
        end

        # Validates that the given options can be serialized for ActiveJob. Walks
        # nested hashes/arrays and accumulates every offending leaf (with its
        # dotted path + class name) before raising — so one error message tells
        # the developer everything that needs fixing.
        def validate_serializable!(options)
          offenders = collect_unserializable(options)
          return if offenders.empty?

          raise NonSerializableArgumentError.new(
            "#{name}.call_async cannot enqueue — the following arguments are not serializable " \
            "for ActiveJob:\n" \
            "#{offenders.map { |entry| "  - #{entry}" }.join("\n")}\n" \
            "Use `.call` (synchronous) instead, or pass only serializable values: primitives, " \
            "Symbols, Date/Time/DateTime, ActiveRecord records (persisted), GlobalID-aware objects, " \
            "Arrays/Hashes of those."
          )
        end

        def collect_unserializable(value, path: nil)
          case value
          when *PRIMITIVE_SERIALIZABLE
            []
          when Hash
            value.flat_map do |key, val|
              sub_path = path ? "#{path}.#{key}" : key.to_s
              collect_unserializable(val, path: sub_path)
            end
          when Array
            value.each_with_index.flat_map do |val, index|
              sub_path = path ? "#{path}[#{index}]" : "[#{index}]"
              collect_unserializable(val, path: sub_path)
            end
          else
            if defined?(BigDecimal) && value.is_a?(BigDecimal)
              []
            elsif defined?(ActiveRecord::Base) && value.is_a?(ActiveRecord::Base)
              value.persisted? ? [] : ["#{path || '(root)'} (unpersisted #{value.class})"]
            elsif value.respond_to?(:to_global_id)
              []
            else
              ["#{path || '(root)'} (#{value.class})"]
            end
          end
        end
      end
    end
  end
end
