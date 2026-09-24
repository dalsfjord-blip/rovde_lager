class VippsClient
  class ConfigurationError < StandardError; end
  class RequestError < StandardError; end

  def initialize(connection: nil)
    @connection = connection
    @client_id = configuration[:client_id]
    @client_secret = configuration[:client_secret]
    @subscription_key = configuration[:subscription_key]
    @merchant_serial_number = configuration[:merchant_serial_number]
    @base_url = configuration[:base_url].presence || "https://apitest.vipps.no"
  end

  def create_payment(reference:, amount_in_oere:, return_url:, phone_number:, description:)
    response = request(:post, "/epayment/v3/payments", {
      amount: { value: amount_in_oere, currency: "NOK" },
      paymentMethod: { type: "VIPPS" },
      customer: { phoneNumber: phone_number },
      returnUrl: return_url,
      userFlow: "WEB_REDIRECT",
      reference: reference,
      paymentDescription: description
    }, idempotency_key: reference)
    response.fetch("redirectUrl")
  end

  def payment_details(reference)
    request(:get, "/epayment/v1/payments/#{ERB::Util.url_encode(reference)}")
  end

  private

  def request(method, path, payload = nil, idempotency_key: nil)
    ensure_configured!
    response = connection.public_send(method, "#{@base_url}#{path}") do |request|
      request.headers["Authorization"] = "Bearer #{access_token}"
      request.headers["Ocp-Apim-Subscription-Key"] = @subscription_key
      request.headers["Merchant-Serial-Number"] = @merchant_serial_number
      request.headers["Content-Type"] = "application/json"
      request.headers["Idempotency-Key"] = idempotency_key if idempotency_key
      request.body = payload.to_json if payload
    end
    raise RequestError, "Vipps returnerte status #{response.status}" unless response.success?

    JSON.parse(response.body)
  rescue JSON::ParserError
    raise RequestError, "Vipps returnerte ugyldig svar"
  end

  def access_token
    Rails.cache.fetch("vipps/access_token", expires_in: 50.minutes) do
      response = connection.post("#{@base_url}/accessToken/v3") do |request|
        request.headers["client_id"] = @client_id
        request.headers["client_secret"] = @client_secret
        request.headers["Ocp-Apim-Subscription-Key"] = @subscription_key
        request.headers["Merchant-Serial-Number"] = @merchant_serial_number
      end
      raise RequestError, "Vipps autentisering feilet" unless response.success?

      JSON.parse(response.body).fetch("access_token")
    end
  end

  def connection
    @connection ||= Faraday.new(request: { open_timeout: 5, timeout: 10 })
  end

  def configuration
    Rails.application.credentials.fetch(:vipps, {}).merge(
      client_id: ENV["VIPPS_CLIENT_ID"],
      client_secret: ENV["VIPPS_CLIENT_SECRET"],
      subscription_key: ENV["VIPPS_SUBSCRIPTION_KEY"],
      merchant_serial_number: ENV["VIPPS_MERCHANT_SERIAL_NUMBER"],
      base_url: ENV["VIPPS_BASE_URL"]
    ) { |_key, credential_value, environment_value| environment_value.presence || credential_value }
  end

  def ensure_configured!
    return if [ @client_id, @client_secret, @subscription_key, @merchant_serial_number ].all?(&:present?)

    raise ConfigurationError, "Vipps-konfigurasjon mangler"
  end
end
