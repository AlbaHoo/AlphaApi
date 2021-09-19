# frozen_string_literal: true

require 'rails/generators/active_record'

module AlphaApi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      desc "Installs AlphaApi"

      source_root File.expand_path("templates", __dir__)

      def copy_initializer
        template "alpha_api.rb.erb", "config/initializers/alpha_api.rb"
      end

      def add_device_initializer
        puts 'Setup device'
        system 'bundle exec rails generate devise:install'
      end

      def create_user_model
        system 'bundle exec rails generate devise User'
      end

      def add_denylisted_token_model
        template "denylisted_token.rb.erb", "app/models/denylisted_token.rb"
      end

      def add_denylisted_token_migration
        migration_template "migration.rb", "db/migrate/add_denylisted_token.rb", migration_version: migration_version
      end

      def initialize_cancancan
        puts 'Setup Cancancan ability class'
        system 'bundle exec rails generate cancan:ability'
      end

      private

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def migration_version
        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      end
    end
  end
end
