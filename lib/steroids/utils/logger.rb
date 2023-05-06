require 'rainbow'

module Steroids
  module Utils
    class Logger
      @notifier = false

      class << self
        attr_accessor :notifier

        def print(input = nil, level: nil, backtrace: nil)
          assert_backtrace(input, backtrace)
          if input.is_a?(Steroids::Base::Error) && input.logged == true
            false
          else
            output = format_input(input)
            level = assert_level(input)
            Rails.logger.send(level, output)
            notify(level, output)
            true
          end
        end

        private

        def assert_level(input)
          return :info unless input.is_a?(Exception)

          if input.is_a?(Steroids::Errors::InternalServerError) || input.is_a?(Steroids::Errors::GenericError)
            :error
          elsif input.is_a?(Steroids::Base::Error)
            :warn
          else
            :error
          end
        end

        def assert_backtrace(input, verbosity)
          @backtrace = input.is_a?(Exception) ? input.backtrace : caller
          @backtrace_verbosity = begin
            if verbosity == nil && input.is_a?(Exception)
              :full
            elsif [:full, :concise, :none].include?(verbosity)
              verbosity
            else
              :none
            end
          end
        end

        def notify(level, input)
          if @notifier.respond_to?(:call) && input.is_a?(Exception) && [:error, :warn].include?(level)
            @notifier.call(input)
          end
        end

        def backtrace_origin
          @backtrace.find do|line|
            !line.include?(".bundle/gems/ruby") && !line.include?("steroids/lib/steroids")
          end
        end

        def format_timestamp(input)
          if input.respond_to?(:timestamp) && input.timestamp.is_a?(DateTime)
            "(at #{input.timestamp.to_time.to_s})"
          end
        end

        def format_message(input)
          [
            "\n#{Rainbow("▶").magenta} #{Rainbow(input.class.to_s).red} -- #{Rainbow(input.message.to_s.upcase_first).magenta}",
            input.respond_to?(:id) && "[ID: #{input.id.to_s}]",
            format_timestamp(input),
          ].compact_blank.join(" ")
        end

        def format_origin
          app_path = "#{Rails.root.to_s}/"
          "  ↳ #{backtrace_origin.to_s.delete_prefix(app_path)}"
        end

        def format_cause(input)
          cause_message = assert_attribute(input, cause_message) || assert_attribute(cause, message) || "Unknown error"
          [
            "  ➤ Cause: #{input.cause.class.name} -- #{cause_message.to_s}",
            input.cause.respond_to?(:record) && input.cause.record && "(#{input.cause.record.class.name})"
          ].compact_blank.join(" ")
        end

        def format_backtrace(input)
          app_path = "#{Rails.root.to_s}/"
          if @backtrace_verbosity == :full
            "  " + @backtrace.map do |path|
              path.to_s.delete_prefix(app_path)
            end.join("\n  ") if @backtrace.any?
          elsif @backtrace_verbosity == :concise
            format_origin
          end
        end

        def format_errors(input)
          record = input.respond_to?(:record) && input.record ? input.record : "Error"
          "  • " + input.errors.map do |error|
            "#{record.class.name}: #{error}"
          end.join("\n  • ") if input.errors.any?
        end

        def format_context(input)
          Rainbow("  ➤ Context: ").cyan + Rainbow(input.context.to_s).blue
        end

        def format_input(input)
          if input.is_a?(Exception)
            [
              format_message(input),
              assert_attribute(input, :errors) && format_errors(input),
              assert_attribute(input, :context) && format_context(input),
              assert_attribute(input, :cause) && format_cause(input),
              [:full, :concise].include?(@backtrace_verbosity) && format_backtrace(input)
            ].compact_blank.join("\n") + "\n"
          else
            [
              input,
              [:full, :concise].include?(@backtrace_verbosity) && format_backtrace(input)
            ].compact_blank.join("\n") + "\n"
          end
        end

        def assert_attribute(instance, key)
          instance.respond_to?(key) && instance.public_send(key)
        end
      end
    end
  end
end
