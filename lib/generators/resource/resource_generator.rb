# frozen_string_literal: true

module AlphaApi
  module Generators
    class ResourceGenerator < Rails::Generators::NamedBase
      desc "Registers resources with AlphaApi"

      class_option :include_boilerplate, type: :boolean, default: false,
                                         desc: "Generate boilerplate code for your resource."

      source_root File.expand_path("templates", __dir__)

      def generate_controller_file
        prefix = AlphaApi.application.settings.api_prefix
        @boilerplate = Boilerplate.new(class_name, prefix)
        template "controller.rb.erb", "app/controllers/#{prefix}/#{file_path.tr('/', '_').pluralize}_controller.rb"
      end

      def generate_serializer_file
        prefix = AlphaApi.application.settings.api_prefix
        @boilerplate = Boilerplate.new(class_name, prefix)
        template "serializer.rb.erb", "app/serializers/#{prefix}/#{file_path.tr('/', '_')}_serializer.rb"
      end
    end

    class Boilerplate
      def initialize(class_name, module_path)
        @module_path = module_path
        @class_name = class_name
      end

      def module_name
        @module_path.split('/').map(&:capitalize).join('::')
      end

      def attributes
        @class_name.constantize.new.attributes.keys
      end

      def assignable_attributes
        attributes - %w(id created_at updated_at)
      end

      def permit_params
        assignable_attributes.map { |a| a.to_sym.inspect }.join(", ")
      end

      def rows
        attributes.map { |a| row(a) }.join("\n  ")
      end

      def row(name)
        "#   row :#{name.gsub(/_id$/, '')}"
      end

      def columns
        attributes.map { |a| column(a) }.join("\n  ")
      end

      def column(name)
        "#   column :#{name.gsub(/_id$/, '')}"
      end

      def filters
        attributes.map { |a| filter(a) }.join("\n  ")
      end

      def filter(name)
        "# filter :#{name.gsub(/_id$/, '')}"
      end

      def form_inputs
        assignable_attributes.map { |a| form_input(a) }.join("\n  ")
      end

      def form_input(name)
        "#     f.input :#{name.gsub(/_id$/, '')}"
      end
    end#
  end
end
