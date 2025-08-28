module Steroids
  module Extensions
    module ProcExtension
      include Steroids::Extensions::MethodExtension
    end
  end
end

Proc.include(Steroids::Extensions::ProcExtension)
