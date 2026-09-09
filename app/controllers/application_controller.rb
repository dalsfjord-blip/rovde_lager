class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :require_pin

  private

  def require_pin
    redirect_to login_path, alert: "Vennligst logg inn med PIN-kode" unless session[:authenticated]
  end

  def current_agreement
    @current_agreement ||= RentalAgreement.includes(:storage_items).find_by(id: session[:rental_agreement_id])
  end

  def start_agreement
    session.delete(:rental_agreement_id)
    @current_agreement = nil
  end

  def store_current_agreement(agreement)
    session[:rental_agreement_id] = agreement.id
    @current_agreement = agreement
  end
end
