module Steroids
  module Base
    class Serializer < ActiveModel::Serializer
      include Steroids::Concerns::Serializer
    end
  end
end
