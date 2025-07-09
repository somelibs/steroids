module Steroids
  module Extensions
    module ClassExtension
      def delegate_alias(alias_name, to:, method:)
        define_method(alias_name) do |*arguments, **options, &block|
          delegate = send(to)
          delegate.send_apply(method, *arguments, **options, &block)
        end
      end
    end
  end
end

Class.include(Steroids::Extensions::ClassExtension)
