module Steroids
  module Base
    class Hash < Steroids::Base::Class
      #include Enumerable # should implement each

      attr_accessor :context

      def initialize
        @context = {}
      end

      def add(object = {})
        @context.merge!(object)
      end

      def <<(object)
        @context.merge!(object)
      end

      def to_json(*_args)
        @context.to_json
      end

      def to_hash
        @context.to_hash
      end

      def merge(object)
        @context.merge(object)
      end

      def merge!(object)
        @context.merge!(object)
      end

      def include?(key)
        @context.include?(key)
      end

      def empty?
        @context.empty?
      end

      def [](key)
        @context[key]
      end
    end
  end
end
