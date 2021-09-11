# frozen_string_literal: true

require_relative "alpha_api/version"
require_relative "alpha_api/application"
require_relative "generators/resource/resource_generator"
require_relative "generators/install/install_generator"
require_relative 'alpha_api/application_settings'

module AlphaApi
  class Error < StandardError; end
  # Your code goes here...

  class << self

    attr_accessor :application

    def application
      @application ||= ::AlphaApi::Application.new
    end

    delegate :register, to: :application

    # Gets called within the initializer
    def setup
      application.before_initializer!
      yield(application)
      application.after_initializer!
    end
  end
end