require "active_support/concern"

module AlphaApi
  module Concerns
    module Actionable
      extend ActiveSupport::Concern

      def create
        authorize! :create, resource_class
        new_resource = build_resource(permitted_create_params)
        if new_resource.valid?
          authorize! :create, new_resource
          new_resource.save
          render status: :created, json: resource_serializer.new(new_resource).serializable_hash
        else
          errors = reformat_validation_error(new_resource)
          raise Exceptions::ValidationErrors.new(errors), 'Validation Errors'
        end
      end

      def index
        authorize! :read, resource_class
        query = apply_filter_and_sort(collection)
        apply_pagination
        if params[:page].present?
          records = paginate(query)
          records = records.padding(params[:page][:offset]) if params[:page][:offset]
        else
          records = query
        end

        options = options(nested_resources, params[:page], query.count)
        render json: resource_serializer.new(records, options).serializable_hash
      end

      def show
        resource = resource_class.find(params[:id])
        authorize! :read, resource
        options = options(nested_resources)
        render json: resource_serializer.new(resource, options).serializable_hash
      end

      def update
        cached_resource_class = resource_class
        resource = cached_resource_class.find(params[:id])
        authorize! :update, resource
        options = options(nested_resources)
        if resource.update(permitted_update_params(resource))
          updated_resource = cached_resource_class.find(params[:id])
          render json: resource_serializer.new(updated_resource, options).serializable_hash
        else
          errors = reformat_validation_error(resource)
          raise Exceptions::ValidationErrors.new(errors), 'Validation Errors'
        end
      end

      def destroy
        if destroyable
          resource = resource_class.find(params[:id])
          authorize! :destroy, resource
          if resource.destroy
            head :no_content
          else
            raise Exceptions::ValidationErrors.new(resource.errors), 'Validation Errors'
          end
        else
          raise Exceptions::MethodNotAllowed, 'Method Not Allowed'
        end
      end

      protected

      def destroyable
        false
      end

      def allowed_associations
        []
      end

      def allowed_sortings
        []
      end

      def apply_filter_and_sort(query)
        query = apply_standard_filter(query) if fields_filter_required?
        # custom filters
        query = apply_filter(query) if params[:filter]
        query = apply_sorting(query)
      end

      # @override customised filters
      def apply_filter(query)
        if filterable_fields.empty?
          raise Exceptions::InvalidFilter, 'Filters are not supported for this resource type'
        else
          query
        end
      end

      def filterable_fields
        []
      end

      def fields_filter_required?
        (params[:search_term] || params[:filter]) && filterable_fields.present?
      end

      # only override this method when filterable_fields is not empty
      def apply_search_term(query, search_term)
        # exclude all _id fields for OR query
        conditions = filterable_fields.select { |field| field_type(field) == :string }.map do |field|
          %("#{resource_class.table_name}"."#{field}" ILIKE #{sanitise(search_term)})
        end
        query = query.where(conditions.join(' OR '))
      end

      def apply_combined_filters(query)
        conditions = []
        filterable_fields.each do |field|
          value = params.dig(:filter, field)
          type = field_type(field)
          next unless value.present? && type.present?
          if type == :uuid || valid_enum?(field, value)
            query = query.where(field => value)
          elsif type == :string
            query = query.where(%("#{resource_class.table_name}"."#{field}" ILIKE #{sanitise(value)}))
          elsif valid_boolean?(field, value)
            query = query.where(field => value == 'true')
          else
            raise Exceptions::InvalidFilter, 'Only type of string and uuid fields are supported'
          end
        end
        query
      end

      def apply_standard_filter(query)
        return query if filterable_fields.empty?
        # generate where clauses of _contains
        search_term = params[:search_term]
        query = if search_term.present?
                  apply_search_term(query, search_term)
                else
                  apply_combined_filters(query)
                end
      end

      def apply_pagination
        page_number = (params.dig(:page, :number) || 1).to_i
        page_offset = (params.dig(:page, :offset) || 0).to_i
        page_size = (params.dig(:page, :size) || 20).to_i

        if allow_all && page_size == -1
          params[:page] = nil
        else
          raise Exceptions::InvalidRequest, 'Page number must be positive' unless page_number.positive?
          raise Exceptions::InvalidRequest, 'Page offset must be non-negative' if page_offset.negative?
          raise Exceptions::InvalidRequest, 'Page size must be positive' unless page_size.positive?
          raise Exceptions::InvalidRequest, 'Page size cannot be greater than 100' if page_size > 100

          params[:page] = {
            number: page_number,
            offset: page_offset,
            size: page_size
          }
        end
      end

      def allow_all
        false
      end

      def apply_sorting(query)
        sort_params = params['sort']
        return query.order(default_sorting) unless sort_params.present?
        raise Exceptions::InvalidRequest, 'Sort parameter must be a string' unless sort_params.is_a? String
        sorting = []

        sorts = sort_params.split(',').map(&:strip).map do |sort|
          is_desc = sort.start_with?('-')
          sort = is_desc ? sort[1..-1] : sort
          raise Exceptions::InvalidRequest, "Sorting by #{sort} is not allowed" unless allowed_sortings.include?(sort.to_sym)
          sort = association_mapper(sort)

          # have to includes the association to be able to sort on
          association = sort.split('.')[-2]
          query = query.includes(association.to_sym) if association

          sorting << sort_clause(sort, is_desc ? 'DESC NULLS LAST' : 'ASC NULLS FIRST')
        end

        query.order(sorting.join(','))
      end

      def association_mapper(sort)
        components = sort.split('.')
        return sort if components.length == 1
        mapper = { 'reseller' => 'organisation' }
        table_name = components[-2]
        "#{mapper[table_name] || table_name}.#{components[-1]}"
      end



      def build_resource(resource_params)
        resource_class.new(resource_params)
      end

      def collection
        resource_class.accessible_by(current_ability)
      end

      def reconcile_nested_attributes(existing_items, items_in_update)
        item_ids_in_update = items_in_update.map { |item| item['id'] }.compact
        if item_ids_in_update.uniq.length != item_ids_in_update.length
          raise(Exceptions::InvalidRequest, 'Nested attribute IDs must be unique')
        end

        nested_attributes = []

        items_in_update.each do |item|
          nested_attributes << reconcile_item(existing_items, item)
        end

        # Existing item was not found in updated items, so should be deleted
        existing_items.reject { |existing| item_ids_in_update.include?(existing.id) }.each do |deleting_item|
          nested_attributes << {
            'id': deleting_item.id,
            '_destroy': true
          }
        end

        nested_attributes
      end

      def resource
         resource_class.find(params[:id])
      end

      def default_sorting
        { created_at: :desc }
      end

      def nested_resources
        nested_resources = params[:include].to_s.split(',')
        invalid_resources = []
        nested_resources.each { |res| invalid_resources.push(res) unless allowed_associations.include?(res.to_sym) }
        unless invalid_resources.empty?
          raise Exceptions::InvalidArgument, "Invalid value for include: #{invalid_resources.join(', ')}"
        end

        nested_resources
      end

      def options(included, page = nil, count = nil)
        options = {
          include: included,
          params: {
            included: included
          }
        }
        options[:meta] = {}
        options[:meta][:total_count] = count if count
        options[:meta][:page_number] = page[:number] if page
        options[:meta][:page_size] = page[:size] if page
        options
      end

      def permitted_create_params
        data = params.require(:data)
        data.require(:attributes) unless data.include?(:attributes)
        data[:attributes]
      end

      def permitted_update_params(_resource)
        data = params.require(:data)
        data.require(:attributes) unless data.include?(:attributes)
        data[:attributes]
      end

      def reconcile_item(existing_items, item)
        item_id = item['id']
        if item_id && !existing_items.find { |i| i.id == item_id }
          # Any unreconciled items in the update need to be re-created
          item.except(:id)
        else
          item
        end
      end

      def reconcile_nested_attributes(existing_items, items_in_update)
        item_ids_in_update = items_in_update.map { |item| item['id'] }.compact
        if item_ids_in_update.uniq.length != item_ids_in_update.length
          raise(Exceptions::InvalidRequest, 'Nested attribute IDs must be unique')
        end

        nested_attributes = []

        items_in_update.each do |item|
          nested_attributes << reconcile_item(existing_items, item)
        end

        # Existing item was not found in updated items, so should be deleted
        existing_items.reject { |existing| item_ids_in_update.include?(existing.id) }.each do |deleting_item|
          nested_attributes << {
            'id': deleting_item.id,
            '_destroy': true
          }
        end

        nested_attributes
      end

      def reformat_validation_error(resource)
        resource.errors
      end

      def resource_class
        controller_name.classify.constantize
      end

      def resource_serializer
        "Api::V1::#{controller_name.classify}Serializer".constantize
      end

      # e.g. sort: 'user.organisation', order: 'desc'
      def sort_clause(sort, order)
        components = sort.split('.')
        attr_name = components[-1]
        if components.length == 1
          # direct attributes
          "#{resource_class.table_name}.#{attr_name} #{order}"
        elsif components.length == 2
          # direct association attributes
          association = resource_class.reflect_on_association(components[-2])
          "#{association.table_name}.#{attr_name} #{order}"
        else
          # could potencially support that as well by includes deeply nested associations
          raise Exceptions::InvalidRequest, 'Sorting on deeply nested association is not supported'
        end
      end

      private

      def field_type(field)
        resource_class.attribute_types[field.to_s].type
      end

      def sanitise(str)
        ActiveRecord::Base.connection.quote("%#{str}%")
      end

      def valid_boolean?(field, value)
        field_type(field) == :boolean && ['true', 'false'].include?(value)
      end

      def valid_enum?(field, value)
        enum = resource_class.defined_enums[field.to_s]
        enum ? enum.keys.include?(value) : false
      end
    end
  end
end
