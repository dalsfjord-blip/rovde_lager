class CustomerInfoController < ApplicationController
  before_action :load_agreement

  def index
    @pickup_dates = [
      { id: "2026-04-01", label: "01. april" },
      { id: "2026-04-30", label: "30. april" },
      { id: "2026-03-19", label: "19. mars kl. 18:00" }
    ]
  end

  def update
    if @agreement.update(customer_info_params)
      redirect_to payment_path, notice: "Kundeinformasjon lagret!"
    else
      @pickup_dates = [
        { id: "2026-04-01", label: "01. april" },
        { id: "2026-04-30", label: "30. april" },
        { id: "2026-03-19", label: "19. mars kl. 18:00" }
      ]
      render :index, status: :unprocessable_entity
    end
  end

  private

  def load_agreement
    @agreement = RentalAgreement.includes(:storage_items).last || RentalAgreement.new
  end

  def customer_info_params
    params.require(:rental_agreement).permit(
      :customer_name,
      :customer_phone,
      :customer_email,
      :pickup_date,
      :special_needs,
      :special_needs_notes,
      :send_email_copy,
      :contract_approved,
      photos: []
    )
  end
end
