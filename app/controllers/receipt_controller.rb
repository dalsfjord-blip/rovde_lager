class ReceiptController < ApplicationController
  before_action :load_agreement

  def show
  end

  def email
    if @agreement.customer_email.present?
      RentalAgreementMailer.confirmation_email(@agreement).deliver_later
      redirect_to receipt_path, notice: "E-post sendt til #{@agreement.customer_email}"
    else
      redirect_to receipt_path, alert: "Ingen e-postadresse registrert."
    end
  rescue StandardError => e
    Rails.logger.error "E-post feilet: #{e.message}"
    redirect_to receipt_path, alert: "E-post kunne ikke sendes. Prøv igjen senere."
  end

  private

  def load_agreement
    @agreement = current_agreement
    redirect_to storage_items_path, alert: "Registrer minst ett lagringsobjekt først." unless @agreement
  end
end
