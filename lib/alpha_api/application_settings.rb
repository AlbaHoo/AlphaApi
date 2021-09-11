# frozen_string_literal: true
require "alpha_api/settings_node"

module AlphaApi
  class ApplicationSettings < SettingsNode

    register :app_path, Rails.root

    register :api_prefix, 'api/v1'

    # Load paths for admin configurations. Add folders to this load path
    # to load up other resources for administration. External gems can
    # include their paths in this load path to provide active_admin UIs
    register :load_paths, []

    # Set default localize format for Date/Time values
    register :localize_format, :long

    # Alpha Api makes educated guesses when displaying objects, this is
    # the list of methods it tries calling in order
    # Note that Formtastic also has 'collection_label_methods' similar to this
    # used by auto generated dropdowns in filter or belongs_to field of Alpha Api
    register :display_name_methods, [ :display_name,
                                      :full_name,
                                      :name,
                                      :username,
                                      :login,
                                      :title,
                                      :email,
                                      :to_s ]

    # Remove sensitive attributes from being displayed, made editable, or exported by default
    register :filter_attributes, [:encrypted_password, :password, :password_confirmation]
  end
end
