require "test_helper"

class VippsWebhooksTest < ActionDispatch::IntegrationTest
  test "captures an authorized payment once and marks it paid after capture" do
    agreement = create_agreement
    payment = { "state" => "AUTHORIZED", "amount" => { "value" => 87_500 } }
    captured_payment = { "state" => "CAPTURED", "amount" => { "value" => 87_500 } }
    calls = []
    vipps_client = Object.new
    vipps_client.define_singleton_method(:payment_details) do |reference|
      calls << [ :payment_details, reference ]
      calls.count { |call| call.first == :payment_details } == 1 ? payment : captured_payment
    end
    vipps_client.define_singleton_method(:capture_payment) do |reference, amount|
      calls << [ :capture_payment, reference, amount ]
      {}
    end

    with_vipps_client(vipps_client) do
      post "/webhooks/vipps", params: { reference: agreement.vipps_reference }
      post "/webhooks/vipps", params: { reference: agreement.vipps_reference }
    end

    assert_response :success
    assert_equal "paid", agreement.reload.payment_status
    assert agreement.paid_at.present?
    assert_equal [ [ :payment_details, agreement.vipps_reference ], [ :capture_payment, agreement.vipps_reference, 87_500 ], [ :payment_details, agreement.vipps_reference ] ], calls
  end

  test "marks a captured webhook as paid before payment details reflect capture" do
    agreement = create_agreement(payment_status: "capture_pending")
    calls = []
    vipps_client = Object.new
    vipps_client.define_singleton_method(:payment_details) do |reference|
      calls << [ :payment_details, reference ]
      { "state" => "AUTHORIZED", "amount" => { "value" => 87_500 } }
    end

    with_vipps_client(vipps_client) do
      post "/webhooks/vipps", params: {
        reference: agreement.vipps_reference,
        name: "CAPTURED",
        amount: { value: 87_500 }
      }
    end

    assert_response :success
    assert_equal "paid", agreement.reload.payment_status
    assert agreement.paid_at.present?
    assert_empty calls
    assert_enqueued_with(job: InvoiceDeliveryJob, args: [ agreement.id, { receipt: true } ])
  end

  test "accepts a correctly signed captured webhook" do
    agreement = create_agreement(payment_status: "capture_pending")
    payload = { reference: agreement.vipps_reference, name: "CAPTURED", amount: { value: 87_500 } }.to_json
    date = "Thu, 25 Sep 2026 08:00:00 GMT"
    content_hash = Base64.strict_encode64(Digest::SHA256.digest(payload))
    signed_string = "POST\n/webhooks/vipps\n#{date};www.example.com;#{content_hash}"
    signature = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", "test-secret", signed_string))

    with_webhook_secret("test-secret") do
      post "/webhooks/vipps", params: payload, headers: {
        "CONTENT_TYPE" => "application/json",
        "HTTP_X_MS_DATE" => date,
        "HTTP_X_MS_CONTENT_SHA256" => content_hash,
        "HTTP_AUTHORIZATION" => "HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature=#{signature}"
      }
    end

    assert_response :success
    assert_equal "paid", agreement.reload.payment_status
  end

  test "rejects a webhook with an invalid signature" do
    agreement = create_agreement

    with_webhook_secret("test-secret") do
      post "/webhooks/vipps", params: { reference: agreement.vipps_reference, name: "CAPTURED" }.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :unauthorized
    assert_equal "payment_pending", agreement.reload.payment_status
  end

  test "does not capture or mark payment paid when the amount differs" do
    agreement = create_agreement
    payment = { "state" => "AUTHORIZED", "amount" => { "value" => 1 } }
    calls = []
    vipps_client = Object.new
    vipps_client.define_singleton_method(:payment_details) do |reference|
      calls << [ :payment_details, reference ]
      payment
    end

    with_vipps_client(vipps_client) do
      post "/webhooks/vipps", params: { reference: agreement.vipps_reference }
    end

    assert_response :success
    assert_equal "payment_pending", agreement.reload.payment_status
    assert_nil agreement.paid_at
    assert_equal [ [ :payment_details, agreement.vipps_reference ] ], calls
  end

  private

  def with_vipps_client(vipps_client)
    VippsClient.define_singleton_method(:new) { |_arguments = nil| vipps_client }
    yield
  ensure
    VippsClient.singleton_class.send(:remove_method, :new)
  end

  def with_webhook_secret(secret)
    original_secret = ENV.fetch("VIPPS_WEBHOOK_SECRET", nil)
    ENV["VIPPS_WEBHOOK_SECRET"] = secret
    yield
  ensure
    ENV["VIPPS_WEBHOOK_SECRET"] = original_secret
  end

  def create_agreement(payment_status: "payment_pending")
    RentalAgreement.create!(
      customer_name: "Ola Nordmann",
      customer_phone: "12345678",
      customer_email: "ola@example.com",
      contract_approved: true,
      total_meters: 1,
      total_price: 700,
      total_price_with_vat: 875,
      vat_amount: 175,
      business_customer: true,
      payment_method: "vipps",
      payment_status: payment_status,
      vipps_reference: "LAG-#{SecureRandom.uuid}"
    )
  end
end
