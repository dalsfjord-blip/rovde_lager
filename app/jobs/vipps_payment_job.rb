class VippsPaymentJob < ApplicationJob
  retry_on VippsClient::RequestError, wait: :polynomially_longer, attempts: 3

  def perform(rental_agreement_id)
    agreement = RentalAgreement.find_by(id: rental_agreement_id)
    return unless agreement&.payment_status == "payment_pending"

    agreement.with_lock do
      return if agreement.vipps_payment_url.present?

      agreement.update!(vipps_reference: agreement.vipps_reference || "LAG-#{agreement.id}-#{SecureRandom.uuid.delete('-')[0, 20].upcase}")
      payment_url = VippsClient.new.create_payment(
        reference: agreement.vipps_reference,
        amount_in_oere: (agreement.total_price_with_vat * 100).round,
        return_url: Rails.application.routes.url_helpers.vipps_callback_payment_url(reference: reference, host: ENV.fetch("APP_HOST", "localhost:3000")),
        phone_number: agreement.customer_phone,
        description: "Sesonglagring #{agreement.reference_number}"
      )
      agreement.update!(vipps_payment_url: payment_url, vipps_payment_created_at: Time.current)
    end
  end
end
