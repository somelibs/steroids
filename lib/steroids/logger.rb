# frozen_string_literal: true

require 'rainbow'

module Steroids
  class Logger
    @notifier = false

    def initialize(input = nil, exception: nil, verbosity: nil, format: :decorated)
      @input = input
      @exception = assert_exception(input, exception)
      @format = assert_format(format)
      @backtrace = assert_backtrace(input, exception, verbosity)
      @level = assert_level(@input)
    end

    def print
      if @input.is_a?(Steroids::Errors::Base) && @input.logged == true
        false
      else
        output = format_input(@level, @input)
        Rails.logger.send(@level, output)
        # Pass the original input (the exception), NOT the formatted output —
        # `notify` filters with `input.is_a?(Exception)` and the formatted
        # output is a plain String.
        notify(@level, @exception || @input)
        true
      end
    end

    private

    def assert_exception(input, exception)
      if exception.is_a?(Exception)
        exception
      else

        input.is_a?(Exception) ? input : nil

      end
    end

    def assert_level(input)
      return :info unless @exception.present?

      if input.is_a?(Steroids::Errors::InternalServerError) || input.is_a?(Steroids::Errors::GenericError)
        :error
      elsif input.is_a?(Steroids::Errors::Base)
        :warn
      else
        :error
      end
    end

    def assert_color(level)
      case level
      when :error
        :red
      when :warn
        :yellow
      when :info
        :green
      end
    end

    def assert_backtrace(_input, _exception, verbosity)
      @backtrace_verbosity = if [:full, :concise, :none].include?(verbosity)
                               verbosity
                             elsif @exception.present?
                               :full
                             else
                               :none
                             end

      @exception.present? ? @exception.backtrace : caller
    end

    def clean_path(input_path)
      root_path_array = Rails.root.to_s.split("/")
      root_path_array.slice!(root_path_array.size - 1..)
      input_path_array = input_path.split("/")
      zipped_array = root_path_array.zip(input_path_array)
      matchs = zipped_array.take_while { |root_path, input_path| root_path == input_path }
      output_path = matchs.map(&:first)
      common_path = output_path.join("/")
      input_path.sub(common_path, '').sub(%r{^/}, '')
    end

    def assert_format(format)
      [:raw, :decorated].include?(format) ? format : :decorated
    end

    def notify(level, input)
      # The notifier is class-level (`Steroids::Logger.notifier = proc`); the
      # instance-side `@notifier` is always unset, so read through the class.
      notifier = self.class.notifier
      if notifier.respond_to?(:call) && input.is_a?(Exception) && [:error, :warn].include?(level)
        notifier.call(input)
      end
    end

    def backtrace_origin
      @backtrace.find do |line|
        !line.include?(".bundle/gems/ruby") && !line.include?("steroids/lib/steroids")
      end
    end

    def format_timestamp(input)
      if input.respond_to?(:timestamp) && input.timestamp.is_a?(DateTime)
        "(at #{input.timestamp.to_time})"
      end
    end

    def format_message(input, exception)
      [
        "\n#{Rainbow("▶").magenta} #{input != exception ? input : nil}",
        "#{Rainbow(exception.class.to_s).red} -- #{Rainbow(exception.message.to_s.upcase_first).magenta}",
        exception.respond_to?(:id) && "[ID: #{exception.id}]",
        format_timestamp(exception),
      ].compact_blank.join(" ")
    end

    def format_origin
      "  ↳ #{clean_path(backtrace_origin.to_s)}"
    end

    def format_cause(input)
      cause_message = assert_attribute(input,
                                       :cause_message) || assert_attribute(input.cause, :message) || "Unknown error"
      [
        Rainbow("\n  ➤ Cause: #{input.cause.class.name}").cyan + " -- #{cause_message}",
        input.cause.respond_to?(:record) && input.cause.record && "(#{input.cause.record.class.name})"
      ].compact_blank.join(" ")
    end

    def format_backtrace(_input)
      if @backtrace_verbosity == :full
        # @backtrace can be nil when the exception was instantiated but never
        # raised (e.g. `StandardError.new("msg")` passed through Logger.print).
        if @backtrace&.any?
          "  " + @backtrace.map do |path|
            clean_path(path.to_s)
          end.join("\n  ")
        end
      elsif @backtrace_verbosity == :concise
        format_origin
      end
    end

    def format_errors(input)
      if input.errors.any?
        "  • " + input.errors.map do |error|
          error_class = input.try(:record) || input.is_a?(Exception) ? input.class.name : "Error"
          "#{error_class}: #{error}"
        end.join("\n  • ")
      end
    end

    def format_context(input)
      Rainbow("  ➤ Context: ").cyan + Rainbow(input.context.to_s).blue
    end

    def format_input(level, input)
      color = assert_color(level)
      if @exception.present?
        [
          format_message(input, @exception),
          assert_attribute(@exception, :errors) && format_errors(input),
          assert_attribute(@exception, :context) && format_context(input),
          [:full, :concise].include?(@backtrace_verbosity) && format_backtrace(@exception),
          assert_attribute(@exception, :cause) && format_cause(@exception)
        ].compact_blank.join("\n") + "\n"
      else
        marker = Rainbow("▶").magenta
        label  = Rainbow("Steroids::Logger").send(color)
        level_label = Rainbow(level.to_s).send(color)
        decorator = "\n#{marker} #{label} -- #{level_label}:"
        [
          @format == :decorated && decorator,
          input,
          [:full, :concise].include?(@backtrace_verbosity) && format_backtrace(input)
        ].compact_blank.join("\n") + "\n"
      end
    end

    def assert_attribute(instance, key)
      instance.respond_to?(key) && instance.public_send(key)
    end

    class << self
      attr_accessor :notifier

      def print(input = nil, exception: nil, verbosity: nil, format: :decorated)
        new(input, exception:, verbosity:, format:).print
      end
    end
  end
end
