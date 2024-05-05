require "zeitwerk"
require "rails"
require "active_model_serializers"

module Steroids
  module Concerns
    autoload :Controller,                   "steroids/concerns/controller"
    autoload :Error,                        "steroids/concerns/error"
    autoload :Model,                        "steroids/concerns/model"
    autoload :Serializer,                   "steroids/concerns/serializer"
  end

  module Base
    autoload :Class,                        "steroids/base/class"
    autoload :Error,                        "steroids/base/error"
    autoload :Hash,                         "steroids/base/hash"
    autoload :List,                         "steroids/base/list"
    autoload :Model,                        "steroids/base/model"
    autoload :Serializer,                   "steroids/base/serializer"
    autoload :Service,                      "steroids/base/service"
    autoload :Type,                         "steroids/base/type"
  end

  module Errors
    autoload :BadRequestError,              "steroids/errors/bad_request_error"
    autoload :ConflictError,                "steroids/errors/conflict_error"
    autoload :ForbiddenError,               "steroids/errors/forbidden_error"
    autoload :GenericError,                 "steroids/errors/generic_error"
    autoload :InternalServerError,          "steroids/errors/internal_server_error"
    autoload :NotFoundError,                "steroids/errors/not_found_error"
    autoload :NotImplementedError,          "steroids/errors/not_implemented_error"
    autoload :UnauthorizedError,            "steroids/errors/unauthorized_error"
    autoload :UnprocessableEntityError,     "steroids/errors/unprocessable_entity_error"
  end

  module Serializers
    autoload :ErrorSerializer,              "steroids/serializers/error_serializer"
  end

  module Utils
    autoload :Types,                        "steroids/utils/types"
    autoload :Logger,                       "steroids/utils/logger"
  end

  module Loader
    def self.zeitwerk
      @loader ||= Zeitwerk::Loader.new.tap do |loader|
        root = File.expand_path("..", __dir__)
        loader.tag = "steroids"
        loader.inflector = Zeitwerk::GemInflector.new("#{root}/steroids.rb")
        loader.enable_reloading
        loader.push_dir(root)
        loader.ignore(
          "#{root}/steroids/railties.rb",
          "#{root}/steroids/version.rb"
        )
      end
    end

    zeitwerk.setup
  end

  def self.root
    File.dirname __dir__
  end
end
