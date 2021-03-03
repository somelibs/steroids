module Steroids
  module Base
    class Hash < Steroids::Base::Class
      attr_accessor :context

      def initialize
        @hash_with_indifferent_access = ActiveSupport::HashWithIndifferentAccess.new
      end

      def add(object = {})
        @hash_with_indifferent_access.merge!(object)
      end

      def <<(object)
        @hash_with_indifferent_access.merge!(object)
      end

      def to_json(*_args)
        @hash_with_indifferent_access.to_json
      end

      def to_hash
        @hash_with_indifferent_access.to_hash
      end

      def merge(object)
        @hash_with_indifferent_access.merge(object)
      end

      def merge!(object)
        @hash_with_indifferent_access.merge!(object)
      end

      def include?(key)
        @hash_with_indifferent_access.include?(key)
      end

      def empty?
        @hash_with_indifferent_access.empty?
      end

      def [](key)
        @hash_with_indifferent_access[key]
      end
    end
  end
end
