module Steroids
  module Extensions
    module SingletonMethods
      extend ActiveSupport::Concern

      included do

      end

      class_methods do
        def singleton(*args)
          puts '----------------------------------------------!xxxxxxxxx!--------!!!!'
          puts '------> Singleton method ' + args.inspect
        end

        def singleton_alias(*)
        end
      end
    end
  end
end
