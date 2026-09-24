class VippsWebhooksController < ApplicationController
  skip_before_action :require_pin
  skip_before_action :verify_authenticity_token

  def receive
    reference = (params[:reference] || params.dig(:payload, :reference)).to_s
    agreement = RentalAgreement.find_by(vipps_reference: reference)
    return head :ok unless agreement

    payment = VippsClient.new.payment_details(reference)
    process_payment(agreement, payment)
    head :ok
  rescue VippsClient::RequestError, VippsClient::ConfigurationError => error
    Rails.logger.error("Vipps webhook kunne ikke verifiseres: #{error.class}")
    head :bad_gateway
  end

  private

  def process_payment(agreement, payment)
    state = payment.dig("state") || payment.dig("paymentDetails", "state")
    amount = payment.dig("amount", "value") || payment.dig("paymentDetails", "amount", "value")
    expected_amount = (agreement.total_price_with_vat * 100).round

    agreement.with_lock do
      return if agreement.paid_at.present?

      case state
      when "CAPTURED"
        return unless amount.to_i == expected_amount

        agreement.update!(payment_status: "paid", paid_at: Time.current)
        InvoiceDeliveryJob.perform_later(agreement.id, receipt: true) if agreement.business_customer? && !agreement.invoice?
      when "AUTHORIZED"
        return unless amount.to_i == expected_amount

        agreement.update!(payment_status: "payment_pending")
      when "ABORTED", "EXPIRED", "TERMINATED"
        agreement.update!(payment_status: "cancelled") if agreement.payment_status == "payment_pending"
      end
    end
  end
end
