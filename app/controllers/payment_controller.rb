class PaymentController < ApplicationController
  before_action :load_agreement, only: [ :show, :create ]

  def show
    render :index
  end

  def create
    if params[:payment_method] == "vipps"
      if Rails.env.development? || Rails.env.test?
        # Simulert betaling for lokal testing
        @agreement.update!(payment_method: "vipps", payment_status: "paid")
        send_confirmation_email
        redirect_to receipt_path, notice: "Betaling fullført (simulert)!"
      else
        # Ekte Vipps-integrasjon
        start_vipps_payment
      end
    else
      redirect_to payment_path, alert: "Ugyldig betalingsmetode"
    end
  end

  # Kunden rutes hit fra Vipps etter gjennomført eller avbrutt betaling
  def vipps_callback
    agreement = RentalAgreement.find_by(id: params[:agreement_id])

    if agreement
      # Webhooken oppdaterer normalt statusen til "paid",
      # men vi sender brukeren til kvitteringen her.
      redirect_to receipt_path, notice: "Takk! Din Vipps-betaling behandles."
    else
      redirect_to payment_path, alert: "Kunne ikke verifisere betalingsavtalen."
    end
  end

  private

  def start_vipps_payment
    vipps = VippsClient.new

    # URL brukeren sendes tilbake til etter godkjenning i Vipps
    return_url = vipps_callback_payment_index_url(agreement_id: @agreement.id)

    response = vipps.create_payment(
      reference: "AGR-#{@agreement.id}-#{SecureRandom.hex(2).upcase}",
      amount_in_nok: @agreement.total_price || 100, # Bruk totalprisen fra avtalen din
      return_url: return_url,
      description: "Leieavtale ##{@agreement.id}"
    )

    if response["redirectUrl"]
      # Lagre betalingsmetode på avtalen mens vi venter på godkjenning
      @agreement.update!(payment_method: "vipps", payment_status: "pending")

      # Send kunden til Vipps sin betalingsside
      redirect_to response["redirectUrl"], allow_other_host: true
    else
      redirect_to payment_path, alert: "Klarte ikke opprette Vipps-betaling."
    end
  rescue StandardError => e
    Rails.logger.error("Vipps Payment Error: #{e.message}")
    redirect_to payment_path, alert: "Kunne ikke kontakte Vipps. Prøv igjen eller velg faktura."
  end

  def load_agreement
    @agreement = current_agreement
    redirect_to storage_items_path, alert: "Registrer minst ett lagringsobjekt først." unless @agreement
  end

  def send_confirmation_email
    if @agreement.send_email_copy && @agreement.customer_email.present?
      RentalAgreementMailer.confirmation_email(@agreement).deliver_later
    end
  end
end
