# frozen_string_literal: true
#
module AlphaApi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Installs AlphaApi"

      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "alpha_api.rb.erb", "config/initializers/alpha_api.rb"
      end

      def something
        puts 'h1'
      end
    end
  end
end
