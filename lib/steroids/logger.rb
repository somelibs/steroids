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
        notify(@level, output)
        true
      end
    end

    private

    def assert_exception(input, exception)
      exception.is_a?(Exception) ? exception : begin
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

    def assert_backtrace(input, exception, verbosity)
      @backtrace_verbosity = begin
        if [:full, :concise, :none].include?(verbosity)
          verbosity
        elsif @exception.present?
          :full
        else
          :none
        end
      end
      @exception.present? ? @exception.backtrace : caller
    end

    def clean_path(input_path)
      root_path_array = Rails.root.to_s.split("/")
      root_path_array.slice!(root_path_array.size-1..)
      input_path_array = input_path.split("/")
      zipped_array = root_path_array.zip(input_path_array)
      matchs = zipped_array.take_while { |root_path, input_path| root_path == input_path }
      output_path = matchs.map(&:first)
      common_path = output_path.join("/")
      input_path.sub(common_path, '').sub(/^\//, '')
    end

    def assert_format(format)
      [:raw, :decorated].include?(format) ? format : :decorated
    end

    def notify(level, input)
      if @notifier.respond_to?(:call) && input.is_a?(Exception) && [:error, :warn].include?(level)
        @notifier.call(input)
      end
    end

    def backtrace_origin
      @backtrace.find do |line|
        !line.include?(".bundle/gems/ruby") && !line.include?("steroids/lib/steroids")
      end
    end

    def format_timestamp(input)
      if input.respond_to?(:timestamp) && input.timestamp.is_a?(DateTime)
        "(at #{input.timestamp.to_time.to_s})"
      end
    end

    def format_message(input, exception)
      [
        "\n#{Rainbow("▶").magenta} #{input != exception ? input : nil}",
        "#{Rainbow(exception.class.to_s).red} -- #{Rainbow(exception.message.to_s.upcase_first).magenta}",
        exception.respond_to?(:id) && "[ID: #{exception.id.to_s}]",
        format_timestamp(exception),
      ].compact_blank.join(" ")
    end

    def format_origin
      "  ↳ #{clean_path(backtrace_origin.to_s)}"
    end

    def format_cause(input)
      cause_message = assert_attribute(input, :cause_message) || assert_attribute(input.cause, :message) || "Unknown error"
      [
        Rainbow("\n  ➤ Cause: #{input.cause.class.name}").cyan + " -- #{cause_message.to_s}",
        input.cause.respond_to?(:record) && input.cause.record && "(#{input.cause.record.class.name})"
      ].compact_blank.join(" ")
    end

    def format_backtrace(input)
      if @backtrace_verbosity == :full
        "  " + @backtrace.map do |path|
          clean_path(path.to_s)
        end.join("\n  ") if @backtrace.any?
      elsif @backtrace_verbosity == :concise
        format_origin
      end
    end

    def format_errors(input)
      "  • " + input.errors.map do |error|
        error_class = input.try(:record) || input.is_a?(Exception) ? input.class.name : "Error"
        "#{error_class}: #{error}"
      end.join("\n  • ") if input.errors.any?
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
        decorator = "\n#{Rainbow("▶").magenta} #{Rainbow("Steroids::Logger").send(color)} -- #{Rainbow(level.to_s).send(color)}:"
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
        self.new(input, exception:, verbosity:, format:).print
      end
    end
  end
end
