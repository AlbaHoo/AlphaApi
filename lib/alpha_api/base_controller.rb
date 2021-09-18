require 'action_pack'
require 'cancancan'
require_relative 'exceptions'

module AlphaApi
  class BaseController < ActionController::API

    rescue_from StandardError do |exception|
      logger.error(exception.message)
      logger.error(exception.backtrace.join("\n"))

      error = error_generator(
        'Internal Server Error',
        'Internal server error.'
      )
      render json: { errors: [error] }, status: :internal_server_error
    end

    rescue_from ActionController::ParameterMissing do |exception|
      error = error_generator(
        'Bad Request',
        "Required parameter '#{exception.param}' is missing."
      )
      render json: { errors: [error] }, status: :bad_request
    end

    rescue_from ActionController::UnpermittedParameters do |exception|
      errors = exception.params.map do |param|
        error_generator(
          'Bad Request',
          "Parameter '#{param}' is not permitted."
        )
      end
      render json: { errors: errors }, status: :bad_request
    end

    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    rescue_from CanCan::AccessDenied, with: :deny_access

    rescue_from AlphaApi::Exceptions::InvalidRequest do |exception|
      error = error_generator('Bad Request', exception.message)
      render json: { errors: [error] }, status: :bad_request
    end

    rescue_from AlphaApi::Exceptions::ValidationErrors, with: :render_validation_errors

    attr_reader :current_auth_token, :current_auth_token_payload, :current_user

    def error_generator(title, detail, source = nil)
      error = { title: title, detail: detail }
      if source
        key_mapper = {
          organisation: 'organisation_id',
          splash: 'splash_id',
          box_hardware: 'box_hardware_id'
        }
        error[:source] = { pointer: "/data/attributes/#{key_mapper[source] || source}" }
      end
      error
    end

    private

    def not_found
      error = error_generator(
        'Not Found',
        "Resource #{request.path} is not found"
      )
      render json: { errors: [error] }, status: :not_found
    end

    def method_not_allowed
      error = error_generator(
        'Method Not Allowed',
        "Method #{request.method} is not allowed on #{request.path}"
      )
      render json: { errors: [error] }, status: :method_not_allowed
    end

    def render_validation_errors(exception)
      unprocessable_entity(exception.errors)
    end

    def deny_access
      forbidden 'You do not have permission to access this resource.'
    end

    def bad_request(reason)
      error = error_generator('Bad Request', reason)
      render json: { errors: [error] }, status: :bad_request
    end

    def forbidden(reason)
      error = error_generator('Forbidden', reason)
      render json: { errors: [error] }, status: :forbidden
    end

    def unauthorized(reason)
      error = error_generator('Unauthorized', reason)
      render json: { errors: [error] }, status: :unauthorized
    end

    def unprocessable_entity(errors)
      errors = errors.map do |attr, message|
        error_generator('Validation Error', message, attr)
      end
      render json: { errors: errors }, status: :unprocessable_entity
    end
  end
end
