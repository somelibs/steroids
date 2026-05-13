module Steroids
  module Support
    module NoticableMethods
      extend ActiveSupport::Concern
      # TODO:
      # do |service, error:,full_notice:| etc
      # error_methods: full_notice success_notice, etc
      # Service: auto log notice
      # error_mothods -> noticable
      # noticable.logger / noticable.log
      # noticable.erros (i.e. delagate error to noticable Noticable.new(self))

      # --------------------------------------------------------------------------------------------
      # TODO
      # To rename collection for notices -> notice -> single message
      # Message alias notice
      # notice can be either error (full message) or success_notice

      # --------------------------------------------------------------------------------------------
      # Noticable exception
      # --------------------------------------------------------------------------------------------

      class RuntimeException < Steroids::Errors::Base
        self.default_message = "Noticable runtime exception"
      end

      # --------------------------------------------------------------------------------------------
      # Noticable collection
      # --------------------------------------------------------------------------------------------

      class NoticableCollection
        NOTICABLE_TYPES = [:errors, :notices]

        attr_reader :collection

        delegate :any?, :map, :each, :to_a, :find, to: :collection

        def initialize(collection_type)
          @collection_type = NOTICABLE_TYPES.cast(collection_type)
          @collection = []
        end

        def add(message_or_exception, exception_or_nil = nil)
          message = message_or_exception.is_a?(Exception) ? message_or_exception.message : message_or_exception
          exception = message_or_exception.is_a?(Exception) ? nil : exception_or_nil
          nil.tap do
            @collection << {
              message: message.typed!(String),
              exception: exception
            }
          end
        end

        def merge(errors)
          nil.tap do
            errors.each do |error|
              @collection << error
            end
          end
        end

        alias << add

        def full_messages
          if @collection.any?
            @collection.map do |error|
              error[:message]
            end.join("\n").presence
          end
        end

        alias messages full_messages
      end

      # --------------------------------------------------------------------------------------------
      # Noticable runtime class (attached to instance)
      # --------------------------------------------------------------------------------------------

      class NoticableRuntime
        # Modes the success notice resolver knows about. `:sync` is the default
        # (set in `initialize`); the `service` macro flips it to `:async` on the
        # un-run preview instance it yields after `.call_async` enqueues.
        DISPATCH_MODES = [:sync, :async].freeze

        # Generic fallbacks when a service did not declare a per-mode notice.
        ASYNC_FALLBACK_NOTICE = "Queued for background processing.".freeze
        # Suffix appended to a plain-String `success_notice` when the dispatch
        # mode is async — so a service that only declared one message still
        # surfaces something accurate ("Newsletter sent (async)") without
        # claiming the work has actually completed yet.
        ASYNC_PLAIN_SUFFIX = " (async)".freeze

        attr_reader :notices, :errors
        attr_accessor :dispatch_mode

        def initialize(concern = [], success_notice: nil, dispatch_mode: :sync)
          @concern = concern
          @success_notice = success_notice
          @dispatch_mode = DISPATCH_MODES.cast(dispatch_mode)
          @errors = NoticableCollection.new(:errors)
          @notices = NoticableCollection.new(:notices)
        end

        def full_messages
          if errors?
            @errors.full_messages
          else
            @notices.full_messages.presence || resolved_success_notice
          end
        end

        alias notice full_messages
        alias message full_messages

        def errors?
          @errors.any?
        end

        def success?
          !errors?
        end

        def flash_key
          errors? ? :alert : :notice
        end

        def merge(noticable)
          @notices.merge(noticable.notices)
          @errors.merge(noticable.errors)
        end

        def to_exception
          cause = @errors.find { |error| error[:exception].present? }
          if errors?
            RuntimeException.new(
              full_messages,
              cause: cause.present? && cause[:exception]
            )
          end
        end

        private

        # Resolves the success notice for the current `@dispatch_mode`.
        #
        # Accepts either form of `success_notice` declaration:
        #   - **String** — applied as-is in sync mode; in async mode, the
        #     " (async)" suffix is appended so the message remains accurate
        #     ("Newsletter sent (async)") without claiming the work is done.
        #   - **Hash with `:sync` and/or `:async` keys** — the key matching the
        #     current mode is used; if missing, falls back to the generic
        #     "Queued for background processing." (async) or the humanized
        #     class-name placeholder (sync).
        def resolved_success_notice
          case @success_notice
          when Hash
            @success_notice[@dispatch_mode].presence || mode_fallback_notice
          when String
            return @success_notice if @dispatch_mode == :sync
            "#{@success_notice}#{ASYNC_PLAIN_SUFFIX}"
          else
            mode_fallback_notice
          end
        end

        def mode_fallback_notice
          @dispatch_mode == :async ? ASYNC_FALLBACK_NOTICE : success_notice_placeholder
        end

        def success_notice_placeholder
          humanized_class_name = @concern.class.name.split("::").last.underscore.humanize
          "#{humanized_class_name} succeeded"
        end
      end

      # --------------------------------------------------------------------------------------------
      # Instance methods
      # --------------------------------------------------------------------------------------------

      included do
        def noticable
          @steroids_noticable_runtime ||= NoticableRuntime.new(
            self,
            success_notice: self.class.steroids_noticable_notice
          )
        end

        delegate :notice, :errors, :notices, :success?, :errors?, :flash_key, to: :noticable
      end

      class_methods do
        attr_reader :steroids_noticable_notice

        def success_notice(message)
          @steroids_noticable_notice ||= message
        end
      end
    end
  end
end
