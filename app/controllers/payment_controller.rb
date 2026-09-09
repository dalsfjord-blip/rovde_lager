class PaymentController < ApplicationController
  before_action :load_agreement

  def index
    # Show payment options
  end

  def create
    if params[:payment_method] == "vipps"
      # In development, simulate Vipps payment
      if Rails.env.development?
        @agreement.payment_method = :vipps
        @agreement.payment_status = :paid
        @agreement.contract_approved = true
        @agreement.save!
        redirect_to receipt_path, notice: "Betaling fullført (simulert)!"
      else
        # TODO: Real Vipps integration
        redirect_to receipt_path, alert: "Vipps-integrasjon ikke konfigurert"
      end
    elsif params[:payment_method] == "invoice"
      @agreement.payment_method = :invoice
      @agreement.payment_status = :pending
      @agreement.contract_approved = true
      @agreement.save!
      redirect_to receipt_path, notice: "Faktura opprettet!"
    else
      redirect_to payment_path, alert: "Vennligst velg betalingsmetode"
    end
  end

  private

  def load_agreement
    @agreement = RentalAgreement.includes(:storage_items).last || RentalAgreement.new
  end
end
