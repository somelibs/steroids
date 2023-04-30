require "rails"
require "active_model_serializers"

require "steroids/railtie"

require "steroids/concerns/controller"
require "steroids/concerns/error"
require "steroids/concerns/model"
require "steroids/concerns/serializer"

require "steroids/base/class"
require "steroids/base/error"
require "steroids/base/hash"
require "steroids/base/list"
require "steroids/base/model"
require "steroids/base/serializer"
require "steroids/base/service"
require "steroids/base/type"

require "steroids/errors/bad_request_error"
require "steroids/errors/conflict_error"
require "steroids/errors/forbidden_error"
require "steroids/errors/generic_error"
require "steroids/errors/internal_server_error"
require "steroids/errors/not_found_error"
require "steroids/errors/not_implemented_error"
require "steroids/errors/unauthorized_error"
require "steroids/errors/unprocessable_entity_error"

require "steroids/serializers/error_serializer"

require "steroids/utils/types"
require "steroids/utils/logger"

module Steroids
  def self.path
    File.dirname __dir__
  end
end
