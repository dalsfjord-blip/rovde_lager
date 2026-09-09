class PaymentController < ApplicationController
  before_action :load_agreement

  def show
    render :index
  end

  def create
    case params[:payment_method]
    when "vipps"
      if Rails.env.development? || Rails.env.test?
        @agreement.update!(payment_method: "vipps", payment_status: "paid")
        redirect_to receipt_path, notice: "Betaling fullført (simulert)!"
      else
        redirect_to payment_path, alert: "Vipps-integrasjon er ikke konfigurert."
      end
    when "invoice"
      @agreement.update!(payment_method: "invoice", payment_status: "pending")
      redirect_to receipt_path, notice: "Faktura opprettet!"
    else
      redirect_to payment_path, alert: "Vennligst velg betalingsmetode"
    end
  end

  private

  def load_agreement
    @agreement = current_agreement
    redirect_to storage_items_path, alert: "Registrer minst ett lagringsobjekt først." unless @agreement
  end
end
