module Steroids
  module Base
    class List < Steroids::Base::Class
      #include Enumerable # should implement each

      attr_accessor :errors

      def initialize
        @errors = []
      end

      def add(object = [])
        add_error(object)
      end

      def <<(object = [])
        add_error(object)
      end

      def to_ary
        @errors
      end

      def to_a
        to_ary
      end

      def any?
        @errors.any?
      end

      def empty?
        @errors.empty?
      end

      private

      def add_error(object = [])
        if object.is_a? ActiveModel::Errors
          formatted = object.to_a.map { |item| item.gsub(/"/, '\'') }
        elsif object.is_a?(Array)
          formatted = object
        elsif object.is_a?(String)
          formatted = [object]
        end
        formatted.each { |item| Rais.logger.info(item) }
        @errors.concat(formatted)
      end
    end
  end
end
