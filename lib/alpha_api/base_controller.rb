module AlphaApi
  class BaseController < ActionController::API
    before_action :verify_auth_token

    rescue_from StandardError do |exception|
      AlphaApi.logger.error(exception.message)
      AlphaApi.logger.error(exception.backtrace.join("\n"))

      error = error_generator(
        'Internal Server Error',
        'Internal server error.'
      )
      render json: { errors: [error] }, status: :internal_server_error
    end

    rescue_from ActiveRecord::DeleteRestrictionError do |exception|
      error = error_generator(
        'Bad Request',
        exception.message
      )
      render json: { errors: [error] }, status: :bad_request
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

    rescue_from AlphaApi::Exceptions::MethodNotAllowed, with: :method_not_allowed

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

    def unsupported_media_type
      head :unsupported_media_type
    end

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

    alias create method_not_allowed
    alias destroy method_not_allowed
    alias index method_not_allowed
    alias update method_not_allowed
    alias show not_found

    def version
      render json: Constants::VERSION
    end

    protected

    def bad_request(reason)
      error = error_generator('Bad Request', reason)
      render json: { errors: [error] }, status: :bad_request
    end

    def forbidden(reason)
      error = error_generator('Forbidden', reason)
      render json: { errors: [error] }, status: :forbidden
    end

    def set_content_type_jsonapi
      response.headers['Content-Type'] = 'application/vnd.api+json; charset=utf-8'
    end

    def set_content_type_json
      response.headers['Content-Type'] = 'application/json; charset=utf-8'
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

    def verify_auth_token
      # Check for HTTP Authorization header
      authorization = request.headers['Authorization']
      AlphaApi.logger.warn "verify_auth_token: authorization #{authorization}"
      return unauthorized '缺少Authorization头文件' unless authorization.present?

      # Extract token from header
      matches = authorization.match(/^Bearer (.+)/)
      token = matches.captures[0] if matches
      return unauthorized 'Authorization头文件错误' unless token.present?

      check_auth_token(token) do |user, payload|
        @current_auth_token = token
        @current_auth_token_payload = payload
        @current_user = user
        nil
      end
    end

    private

    def check_auth_token(token)
      # Attempt to decode the auth token payload
      payload = nil
      begin
        payload = Warden::JWTAuth::TokenDecoder.new.call token
      rescue JWT::ExpiredSignature
        payload = JWT.decode(token, nil, false)[0]
        unless payload['aud'] == 'mobile'
          return unauthorized '验证信息已经过期，请重新登陆.'
        end
      rescue StandardError => e
        AlphaApi.logger.warn "Failed to decode authentication token: #{e.message}, token: #{token}"
        return unauthorized '验证信息错误'
      end

      return unauthorized '验证信息错误' unless payload

      # Check that token is still valid
      user = User.find_by(id: payload['user_id'])
      return unauthorized '验证信息错误' unless user
      return unauthorized '验证信息已无效' if DenylistedToken.jwt_revoked?(payload, user)

      yield user, payload
    end

    def render_validation_errors(exception)
      unprocessable_entity(exception.errors)
    end

    def deny_access
      forbidden '没有权限访问该资源'
    end
  end
end
