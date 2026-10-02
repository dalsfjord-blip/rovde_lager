class HarborRentalsController < ApplicationController
  layout "landing"

  helper_method :current_user

  skip_before_action :require_pin
  before_action :require_harbor_user, only: [ :show, :create ]

  def login
    redirect_to harbor_rental_path if current_user
  end

  def show
    @harbor_rental = current_user.harbor_rentals.build
  end

  def create
    @harbor_rental = current_user.harbor_rentals.build(harbor_rental_params)
    @harbor_rental.payment_status = "invoice_pending"

    if @harbor_rental.save
      HarborRentalInvoiceDeliveryJob.perform_later(@harbor_rental.id)
      redirect_to harbor_rental_path, notice: "Fakturaen vert send til fakturaadressa di."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_harbor_user
    return if current_user

    redirect_to harbor_rental_login_path, alert: "Logg inn med Vipps for å registrere hamneleige."
  end

  def harbor_rental_params
    params.require(:harbor_rental).permit(
      :days,
      :billing_company_name,
      :billing_organization_number,
      :billing_email,
      :comments
    )
  end
end
