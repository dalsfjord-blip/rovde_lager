class ReceiptController < ApplicationController
  def show
    @agreement = RentalAgreement.includes(:storage_items).last || RentalAgreement.new
  end

  def email
    @agreement = RentalAgreement.includes(:storage_items).find(params[:id])
    # TODO: Implement actual email sending
    redirect_to receipt_path, notice: "Kontrakt sendt på e-post!"
  end
end
