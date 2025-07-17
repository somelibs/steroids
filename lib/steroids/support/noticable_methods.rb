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
      # Noticable collection
      # --------------------------------------------------------------------------------------------

      class NoticableCollection
        NOTICABLE_TYPES = %i[errors notices]

        attr_reader :collection

        delegate :any?, :map, :to_a, to: :collection

        def initialize(collection_type)
          @collection_type = NOTICABLE_TYPES.cast(collection_type)
          @collection = []
        end

        def add(message, exception = nil)
          nil.tap do
            @collection << {
              message: message.typed!(String),
              exception: exception
            }
          end
        end

        alias_method :<<, :add

        def full_messages
          if @collection.any?
            @collection.map do |error|
              error[:message]
            end.join("\n").presence
          end
        end
      end

      # --------------------------------------------------------------------------------------------
      # Noticable class
      # --------------------------------------------------------------------------------------------

      class NoticableRuntime
        attr_reader :errors
        attr_reader :notices

        def initialize(concern = [], success_notice: nil)
          @concern = concern
          @success_notice = success_notice.presence || success_notice_placeholder
          @errors = NoticableCollection.new(:errors)
          @notices = NoticableCollection.new(:notices)
        end

        def full_messages
          @errors.full_messages.presence || @success_notice
        end

        alias_method :full_message, :full_messages

        def errors?
          @errors.any?
        end

        def success?
          !errors?
        end

        def to_s
          full_messages
        end

        private

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

        delegate :errors, :notices, to: :noticable

        alias_method :notice, :notices
        alias_method :error, :errors
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
