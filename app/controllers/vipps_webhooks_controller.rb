class VippsWebhooksController < ApplicationController
  skip_before_action :require_pin
  skip_before_action :verify_authenticity_token

  def receive
    return head :unauthorized unless valid_webhook_signature?

    reference = (params[:reference] || params.dig(:payload, :reference)).to_s
    agreement = RentalAgreement.find_by(vipps_reference: reference)
    return head :ok unless agreement

    process_webhook(agreement)
    head :ok
  rescue VippsClient::RequestError, VippsClient::ConfigurationError => error
    Rails.logger.error("Vipps webhook kunne ikke verifiseres: #{error.class}")
    head :bad_gateway
  end

  private

  def valid_webhook_signature?
    secret = ENV["VIPPS_WEBHOOK_SECRET"]
    return true if secret.blank? && !Rails.env.production?
    return false if secret.blank?

    content_hash = request.headers["x-ms-content-sha256"]
    authorization = request.headers["Authorization"].to_s
    signature = authorization[/\ASignature=(.+)\z/, 1] || authorization[/&Signature=(.+)\z/, 1]
    return false if content_hash.blank? || signature.blank?
    return false unless ActiveSupport::SecurityUtils.secure_compare(Base64.strict_encode64(Digest::SHA256.digest(request.raw_post)), content_hash)

    signed_string = "POST\n#{request.fullpath}\n#{request.headers['x-ms-date']};#{request.host};#{content_hash}"
    expected_signature = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", secret, signed_string))
    ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
  end

  def process_webhook(agreement)
    state = (params[:name] || params.dig(:payload, :name)).to_s
    amount = params.dig(:amount, :value) || params.dig(:payload, :amount, :value)
    expected_amount = (agreement.total_price_with_vat * 100).round

    return mark_payment_paid(agreement, expected_amount) if state == "CAPTURED" && amount.to_i == expected_amount

    payment = VippsClient.new.payment_details(agreement.vipps_reference)
    process_payment(agreement, payment)
  end

  def process_payment(agreement, payment)
    state = payment.dig("state") || payment.dig("paymentDetails", "state")
    amount = payment.dig("amount", "value") || payment.dig("paymentDetails", "amount", "value")
    expected_amount = (agreement.total_price_with_vat * 100).round

    case state
    when "AUTHORIZED"
      capture_payment(agreement, expected_amount) if amount.to_i == expected_amount
    when "CAPTURED"
      mark_payment_paid(agreement, expected_amount) if amount.to_i == expected_amount
    when "ABORTED", "EXPIRED", "TERMINATED"
      cancel_payment(agreement)
    end
  end

  def capture_payment(agreement, expected_amount)
    should_capture = agreement.with_lock do
      next false if agreement.paid_at.present? || agreement.payment_status == "capture_pending"

      agreement.update!(payment_status: "capture_pending")
      true
    end
    return unless should_capture

    VippsClient.new.capture_payment(agreement.vipps_reference, expected_amount)
  rescue VippsClient::RequestError, VippsClient::ConfigurationError
    agreement.with_lock do
      agreement.update!(payment_status: "payment_pending") unless agreement.paid_at.present?
    end
    raise
  end

  def mark_payment_paid(agreement, expected_amount)
    agreement.with_lock do
      return if agreement.paid_at.present?
      return unless (agreement.total_price_with_vat * 100).round == expected_amount

      agreement.update!(payment_status: "paid", paid_at: Time.current)
      InvoiceDeliveryJob.perform_later(agreement.id, receipt: true) if agreement.business_customer? && !agreement.invoice?
    end
  end

  def cancel_payment(agreement)
    agreement.with_lock do
      agreement.update!(payment_status: "cancelled") if %w[payment_pending capture_pending].include?(agreement.payment_status)
    end
  end
end
