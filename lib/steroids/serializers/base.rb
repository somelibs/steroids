module Steroids
  module Serializers
    class Base < ActiveModel::Serializer
      include Steroids::Serializers::Methods
    end
  end
end
