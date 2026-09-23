class VippsWebhooksController < ApplicationController
  # Hopp over krav om PIN-innlogging og Rails CSRF-token for eksterne kall fra Vipps
  skip_before_action :require_pin
  skip_before_action :verify_authenticity_token

  def receive
    payload = params[:payload] || {}
    reference = payload[:reference] # F.eks. "AGR-12-A1B2"
    state = payload[:state]         # F.eks. "AUTHORIZED", "TERMINATED", "ABORTED"

    Rails.logger.info("Vipps Webhook mottatt for #{reference}: #{state}")

    # Hent ut avtale-ID fra referansen (AGR-12-A1B2 -> 12)
    if reference.present? && reference.start_with?("AGR-")
      agreement_id = reference.split("-")[1]
      agreement = RentalAgreement.find_by(id: agreement_id)

      if agreement
        case state
        when "AUTHORIZED"
          agreement.update!(payment_status: "paid")
        when "TERMINATED", "ABORTED", "EXPIRED"
          agreement.update!(payment_status: "failed")
        end
      end
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error("Vipps Webhook Error: #{e.message}")
    head :internal_server_error
  end
end
