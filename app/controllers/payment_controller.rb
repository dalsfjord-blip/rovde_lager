class PaymentController < ApplicationController
  before_action :load_agreement, only: [ :show, :create ]
  skip_before_action :require_pin, only: :status
  skip_before_action :verify_authenticity_token, only: :complete_demo

  def show
    render :index
  end

  def create
    redirect_to storage_items_path(new: true), alert: "Betaling startes fra registreringsskjemaet."
  end

  def vipps_callback
    redirect_to storage_items_path(new: true), notice: "Vipps-betalingen behandles."
  end

  def status
    agreement = RentalAgreement.find_by(vipps_reference: params[:reference])
    return head :not_found unless agreement

    if %w[paid cancelled failed].include?(agreement.payment_status)
      session.delete(:vipps_payment_url)
      session.delete(:vipps_reference)
    end
    render json: { status: agreement.payment_status }
  end

  def dismiss
    session.delete(:vipps_payment_url)
    session.delete(:vipps_reference)
    head :no_content
  end

  def complete_demo
    return head :not_found unless Rails.env.development?

    agreement = RentalAgreement.find_by(vipps_reference: params[:reference])
    return head :not_found unless agreement&.payment_status == "payment_pending"

    agreement.with_lock do
      agreement.update!(payment_status: "paid", paid_at: Time.current)
      InvoiceDeliveryJob.perform_later(agreement.id, receipt: true) if agreement.business_customer?
    end
    head :no_content
  end

  private

  def start_vipps_payment
    vipps = VippsClient.new

    # URL brukeren sendes tilbake til etter godkjenning i Vipps
    return_url = "https://vipps.no"

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
end
