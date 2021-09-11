# frozen_string_literal: true
require "alpha_api/dynamic_settings_node"

module AlphaApi
  class NamespaceSettings < DynamicSettingsNode
    # The default number of resources to display on index pages
    register :default_per_page, 30

    # The max number of resources to display on index pages and batch exports
    register :max_per_page, 10_000

    # The title which gets displayed in the main layout
    register :site_title, "", :string_symbol_or_proc

    # The method to call in controllers to get the current user
    register :current_user_method, false

    # The method to call in the controllers to ensure that there
    # is a currently authenticated admin user
    register :authentication_method, false

    # Whether filters are enabled
    register :filters, true

    # Request parameters that are permitted by default
    register :permitted_params, [
      :utf8, :_method, :authenticity_token, :commit, :id
    ]

    # Include association filters by default
    register :include_default_association_filters, true

    register :maximum_association_filter_arity, :unlimited
  end
end
