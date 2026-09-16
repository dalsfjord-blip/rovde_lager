# app/services/vipps_client.rb
class VippsClient
  BASE_URL = Rails.application.credentials.dig(:vipps, :base_url) || "https://apitest.vipps.no"

  def initialize
    @client_id = Rails.application.credentials.dig(:vipps, :client_id)
    @client_secret = Rails.application.credentials.dig(:vipps, :client_secret)
    @subscription_key = Rails.application.credentials.dig(:vipps, :subscription_key)
    @msn = Rails.application.credentials.dig(:vipps, :merchant_serial_number)
  end

  # PUBLIC METODER (må stå over "private")
  def access_token
    Rails.cache.fetch("vipps_access_token", expires_in: 55.minutes) do
      fetch_new_access_token
    end
  end

  def create_payment(reference:, amount_in_nok:, return_url:, phone_number: "47000000", description: "Kjøp i app")
    amount_in_oere = (amount_in_nok * 100).to_i

    payload = {
      amount: { value: amount_in_oere, currency: "NOK" },
      paymentMethod: { type: "VIPPS" },
      customer: { phoneNumber: phone_number },
      returnUrl: return_url,
      userFlow: "WEB_REDIRECT",
      reference: reference.to_s,
      paymentDescription: description
    }

    response = Faraday.post("#{BASE_URL}/epayment/v3/payments") do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
      req.headers["Ocp-Apim-Subscription-Key"] = @subscription_key
      req.headers["Merchant-Serial-Number"] = @msn
      req.headers["Idempotency-Key"] = SecureRandom.uuid
      req.headers["Content-Type"] = "application/json"
      req.body = payload.to_json
    end

    if response.success?
      JSON.parse(response.body)
    else
      Rails.logger.error("Vipps Payment Error: #{response.status} - #{response.body}")
      raise "Klarte ikke opprette Vipps-betaling: #{response.body}"
    end
  end

  private # Alt under her blir skjult for omverdenen

  def fetch_new_access_token
    response = Faraday.post("#{BASE_URL}/accessToken/v3") do |req|
      req.headers["client_id"] = @client_id
      req.headers["client_secret"] = @client_secret
      req.headers["Ocp-Apim-Subscription-Key"] = @subscription_key
      req.headers["Merchant-Serial-Number"] = @msn
    end

    if response.success?
      json = JSON.parse(response.body)
      json["access_token"]
    else
      Rails.logger.error("Vipps Auth Error: #{response.status} - #{response.body}")
      raise "Klarte ikke hente Vipps access_token: #{response.body}"
    end
  end
end
