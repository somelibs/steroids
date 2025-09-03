require 'test_helper'

class SteroidsTest < ActiveSupport::TestCase
  test "Steroids module exists" do
    assert_kind_of Module, Steroids
  end
  
  test "Steroids has version number" do
    assert Steroids::VERSION
  end
  
  test "core modules are loaded" do
    assert Steroids::Services
    assert Steroids::Services::Base
    assert Steroids::Errors
    assert Steroids::Errors::Base
    assert Steroids::Support::NoticableMethods
    assert Steroids::Support::ServicableMethods
    assert Steroids::Logger
  end
  
  test "error classes are defined" do
    assert Steroids::Errors::BadRequestError
    assert Steroids::Errors::UnauthorizedError
    assert Steroids::Errors::ForbiddenError
    assert Steroids::Errors::NotFoundError
    assert Steroids::Errors::ConflictError
    assert Steroids::Errors::UnprocessableEntityError
    assert Steroids::Errors::InternalServerError
    assert Steroids::Errors::NotImplementedError
  end
end
