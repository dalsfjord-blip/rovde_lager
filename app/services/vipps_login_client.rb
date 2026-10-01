class VippsLoginClient
  ACCESS_MANAGEMENT_PATH = "/access-management-1.0/access"
  USERINFO_PATH = "/vipps-userinfo-api/userinfo/"

  class ConfigurationError < StandardError; end
  class RequestError < StandardError; end

  def redirect_uri(default:)
    configuration[:redirect_uri].presence || default
  end

  def authorization_url(state:, code_verifier:, redirect_uri:)
    ensure_configured!

    query = URI.encode_www_form(
      client_id: client_id,
      response_type: "code",
      redirect_uri: redirect_uri,
      scope: "openid name email phoneNumber",
      state: state,
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false),
      code_challenge_method: "S256"
    )
    "#{authorization_endpoint}?#{query}"
  end

  def profile(code:, code_verifier:, redirect_uri:)
    token = exchange_code(code:, code_verifier:, redirect_uri:)
    access_token = token.fetch("access_token")
    response = connection.get(userinfo_endpoint) do |request|
      request.headers["Authorization"] = "Bearer #{access_token}"
    end
    raise RequestError, "Vipps Login returnerte status #{response.status}" unless response.success?

    payload = JSON.parse(response.body)
    {
      name: payload["name"].to_s,
      email: payload["email"].to_s.downcase,
      phone_number: payload["phone_number"] || payload["phoneNumber"]
    }
  rescue JSON::ParserError, KeyError
    raise RequestError, "Vipps Login returnerte ugyldig svar"
  end

  private

  def exchange_code(code:, code_verifier:, redirect_uri:)
    credentials = Base64.strict_encode64("#{client_id}:#{client_secret}")
    response = connection.post(token_endpoint) do |request|
      request.headers["Content-Type"] = "application/x-www-form-urlencoded"
      request.headers["Authorization"] = "Basic #{credentials}"
      request.body = URI.encode_www_form(
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        code_verifier: code_verifier
      )
    end
    raise RequestError, "Vipps Login returnerte status #{response.status}" unless response.success?

    JSON.parse(response.body)
  end

  def ensure_configured!
    return if [ client_id, client_secret, authorization_endpoint, token_endpoint, userinfo_endpoint ].all?(&:present?)

    raise ConfigurationError, "Vipps Login-konfigurasjon mangler"
  end

  def connection
    @connection ||= Faraday.new(request: { open_timeout: 5, timeout: 10 })
  end

  def base_url
    ENV.fetch("VIPPS_LOGIN_BASE_URL", ENV.fetch("VIPPS_BASE_URL", "https://api.vipps.no")).chomp("/")
  end

  def client_id
    configuration[:client_id]
  end

  def client_secret
    configuration[:client_secret]
  end

  def authorization_endpoint
    configuration[:authorization_endpoint]
  end

  def token_endpoint
    configuration[:token_endpoint]
  end

  def userinfo_endpoint
    configuration[:userinfo_endpoint]
  end

  def configuration
    Rails.application.credentials.fetch(:vipps_login, {}).merge(
      client_id: ENV["VIPPS_LOGIN_CLIENT_ID"].presence || ENV["VIPPS_CLIENT_ID"],
      client_secret: ENV["VIPPS_LOGIN_CLIENT_SECRET"].presence || ENV["VIPPS_CLIENT_SECRET"],
      authorization_endpoint: ENV["VIPPS_LOGIN_AUTHORIZATION_ENDPOINT"].presence || "#{base_url}#{ACCESS_MANAGEMENT_PATH}/oauth2/auth",
      token_endpoint: ENV["VIPPS_LOGIN_TOKEN_ENDPOINT"].presence || "#{base_url}#{ACCESS_MANAGEMENT_PATH}/oauth2/token",
      userinfo_endpoint: ENV["VIPPS_LOGIN_USERINFO_ENDPOINT"].presence || "#{base_url}#{USERINFO_PATH}",
      redirect_uri: ENV["VIPPS_LOGIN_REDIRECT_URI"]
    ) { |_key, credential_value, environment_value| environment_value.presence || credential_value }
  end
end
