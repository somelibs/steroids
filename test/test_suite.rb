# Run all Steroids tests
# Usage: ruby test/test_suite.rb

require_relative 'test_helper'

# Load all test files
Dir[File.expand_path('../**/*_test.rb', __FILE__)].each do |test_file|
  require test_file
end

# Run tests
if ARGV.include?('--verbose')
  Minitest.run(['--verbose'])
else
  Minitest.run
end