module AlphaApi
  module Exceptions
    class InvalidRequest < StandardError; end
    class InvalidFilter < InvalidRequest; end
    class InvalidArgument < InvalidRequest; end
    class MethodNotAllowed < StandardError; end
    class ValidationErrors < StandardError
      attr_reader :errors

      def initialize(errors = [])
        super
        @errors = errors
      end
    end
  end
end
