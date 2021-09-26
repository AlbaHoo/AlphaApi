# frozen_string_literal: true
require "alpha_api/application_settings"
require "alpha_api/namespace_settings"
require 'api-pagination'

module AlphaApi
  class Application

    class << self
      def setting(name, default)
        ApplicationSettings.register name, default
      end

      def inheritable_setting(name, default)
        NamespaceSettings.register name, default
      end
    end

    def respond_to_missing?(method, include_private = false)
      [settings, namespace_settings].any? { |sets| sets.respond_to?(method) } || super
    end

    def method_missing(method, *args)
      if settings.respond_to?(method)
        settings.send(method, *args)
      elsif namespace_settings.respond_to?(method)
        namespace_settings.send(method, *args)
      else
        super
      end
    end

    def settings
      @settings ||= SettingsNode.build(ApplicationSettings)
    end

    def namespace_settings
      @namespace_settings ||= SettingsNode.build(NamespaceSettings)
    end

    def initialize
    end

    # Runs before the app's initializer
    def before_initializer!
      # puts 'before initializer'
      ApiPagination.configure do |config|
        config.page_param do |params|
          if params[:page].is_a?(ActionController::Parameters) && params[:page].include?(:number)
            params[:page][:number]
          else
            1
          end
        end

        config.per_page_param do |params|
          if params[:page].is_a?(ActionController::Parameters) && params[:page].include?(:size)
            params[:page][:size]
          else
            10
          end
        end
      end
    end

    # Runs after the app's initializer
    def after_initializer!
      # puts 'after initializer'
    end

    private
  end
end

